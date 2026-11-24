
// Nexions updater stage 1: read-only device checks, ephemeral local signing probe,
// and verified download of a newer, explicitly versioned release. No install or certificate change.
import CryptoKit
import Security

private struct NXRelease: Decodable {
    let tag_name: String
    let draft: Bool
    let assets: [NXAsset]
}
private struct NXAsset: Decodable {
    let name: String
    let size: Int
    let browser_download_url: URL
    let digest: String?
}

@MainActor private struct NexionsUpdaterView: View {
    let appleToken: Bool
    let signedUntil: Date?
    @State private var status = "Not checked"
    @State private var keyStatus = "Not tested"
    @State private var busy = false
    @State private var candidate: NXAsset?
    @State private var candidateTag = ""
    private var currentBuild: Int {
        Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "") ?? 0
    }
    private var helperID: String? {
        Bundle(url: Bundle.main.bundleURL.appendingPathComponent("PlugIns/SPJitHelper.appex"))?.bundleIdentifier
    }
    private var appID: String { Bundle.main.bundleIdentifier ?? "Unknown" }
    private var sameIdentity: Bool { helperID == appID + ".helper" }
    private var hasProfiles: Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: Bundle.main.bundleURL.appendingPathComponent("embedded.mobileprovision").path)
            && fm.fileExists(atPath: Bundle.main.bundleURL.appendingPathComponent("PlugIns/SPJitHelper.appex/embedded.mobileprovision").path)
    }
    var body: some View {
        List {
            Section("Installed app") {
                LabeledContent("Build", value: String(currentBuild))
                LabeledContent("Bundle ID", value: appID)
                LabeledContent("Helper ID", value: helperID ?? "Missing")
                LabeledContent("Identity layout", value: sameIdentity ? "Matches" : "Mismatch")
                LabeledContent("Embedded profiles", value: hasProfiles ? "Both present" : "Missing")
                LabeledContent("Apple token", value: appleToken ? "Present" : "Missing")
                if let until = signedUntil {
                    LabeledContent("Signed until", value: until.formatted(date: .abbreviated, time: .omitted))
                }
            }
            Section("Local signing test") {
                Button("Test local signing key") { probeKey() }
                Text(keyStatus).font(.footnote)
                Text("Creates a temporary key, signs a test message and verifies it locally. Does not contact Apple, modify certificates, or sign an app.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("GitHub updates") {
                Button("Check for updates") { Task { await checkUpdates() } }.disabled(busy)
                if busy { ProgressView() }
                Text(status).font(.footnote)
                if let asset = candidate {
                    LabeledContent("Available", value: candidateTag)
                    LabeledContent("Download", value: ByteCountFormatter.string(fromByteCount: Int64(asset.size), countStyle: .file))
                    Button("Download and verify") { Task { await download(asset) } }.disabled(busy)
                }
            }
            Section("Installation") {
                Text("Experimental stage 1. App signing and on-device installation are not implemented. Use Windows Companion to install updates without deleting the current app.").font(.footnote)
            }
        }
        .navigationTitle("Nexions Updater")
        .navigationBarTitleDisplayMode(.inline)
    }
    private func probeKey() {
        let attrs: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecPrivateKeyAttrs as String: [kSecAttrIsPermanent as String: false]
        ]
        var error: Unmanaged<CFError>?
        let message = Data("Nexions updater local test".utf8) as CFData
        guard let key = SecKeyCreateRandomKey(attrs as CFDictionary, &error),
              let pub = SecKeyCopyPublicKey(key),
              let sig = SecKeyCreateSignature(key, .ecdsaSignatureMessageX962SHA256, message, &error),
              SecKeyVerifySignature(pub, .ecdsaSignatureMessageX962SHA256, message, sig, &error) else {
            keyStatus = "Failed: " + (error?.takeRetainedValue().localizedDescription ?? "Key/signature verification failed")
            return
        }
        keyStatus = "PASS: temporary local key and signature verified. App signing not tested."
    }
    private func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.allowsCellularAccess = false
        config.waitsForConnectivity = false
        config.timeoutIntervalForRequest = 45
        return URLSession(configuration: config)
    }
    private func build(_ tag: String) -> Int? {
        let prefix = "nexions-v1.7.0-alpha"
        guard tag.hasPrefix(prefix), let n = Int(tag.dropFirst(prefix.count)), (1...99).contains(n) else { return nil }
        return 1700 + n
    }
    private func digest(_ asset: NXAsset) -> String? {
        guard let value = asset.digest, value.hasPrefix("sha256:") else { return nil }
        let hash = String(value.dropFirst(7)).lowercased()
        guard hash.count == 64, hash.allSatisfy({ "0123456789abcdef".contains($0) }) else { return nil }
        return hash
    }
    private func allowed(_ asset: NXAsset, tag: String) -> Bool {
        let url = asset.browser_download_url
        return asset.name == "slashplayed-device-kit.zip"
            && url.scheme == "https" && url.host == "github.com"
            && url.path == "/Nexions-link/slashplayed-enhanced/releases/download/\(tag)/slashplayed-device-kit.zip"
            && asset.size > 0 && asset.size <= 128 * 1024 * 1024 && digest(asset) != nil
    }
    private func checkUpdates() async {
        guard !busy else { return }
        busy = true; candidate = nil; candidateTag = ""; status = "Checking GitHub over Wi-Fi…"
        let client = session()
        defer { busy = false; client.finishTasksAndInvalidate() }
        do {
            let url = URL(string: "https://api.github.com/repos/Nexions-link/slashplayed-enhanced/releases?per_page=30")!
            var req = URLRequest(url: url)
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await client.data(for: req)
            guard (response as? HTTPURLResponse)?.statusCode == 200, data.count <= 2_000_000 else {
                status = "GitHub check failed (HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0))."; return
            }
            let releases = try JSONDecoder().decode([NXRelease].self, from: data)
            let newer = releases.filter { !$0.draft && (build($0.tag_name) ?? 0) > currentBuild }
                .sorted { (build($0.tag_name) ?? 0) > (build($1.tag_name) ?? 0) }
            for release in newer {
                if let asset = release.assets.first(where: { allowed($0, tag: release.tag_name) }) {
                    candidate = asset; candidateTag = release.tag_name
                    status = "Newer release with SHA-256 digest found."; return
                }
            }
            status = newer.isEmpty ? "No newer published Nexions release." : "Newer release has no eligible Device Kit with SHA-256 digest."
        } catch { status = "Check failed: \(error.localizedDescription)" }
    }
    private func download(_ asset: NXAsset) async {
        guard !busy, sameIdentity, hasProfiles, allowed(asset, tag: candidateTag),
              let expected = digest(asset) else { status = "Preflight refused."; return }
        busy = true; status = "Downloading over Wi-Fi…"
        let client = session()
        defer { busy = false; client.finishTasksAndInvalidate() }
        do {
            let (url, response) = try await client.download(from: asset.browser_download_url)
            defer { try? FileManager.default.removeItem(at: url) }
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  (try url.resourceValues(forKeys: [.fileSizeKey])).fileSize == asset.size else {
                status = "Download size or HTTP status mismatch."; return
            }
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            var hash = SHA256()
            while let chunk = try handle.read(upToCount: 1024 * 1024), !chunk.isEmpty { hash.update(data: chunk) }
            let actual = hash.finalize().map { String(format: "%02x", $0) }.joined()
            guard actual == expected else { status = "SHA-256 mismatch. Package discarded."; return }
            status = "PASS: downloaded \(asset.size) bytes, SHA-256 matches GitHub. Temporary archive discarded; nothing installed."
        } catch { status = "Download failed: \(error.localizedDescription)" }
    }
}
