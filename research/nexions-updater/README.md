# On-device update experiment

Base: Nexions 1.7.0 Alpha 2 (0ae588ea4f215cfd30756b12a7c673df9809ab74).
Upstream: Slashplayed v1.7.0 (0e68bb83766c0a47aae4980fdab78e09ddcc91f1).
Reference for research only: FrizzleM/SideInstaller @ 08936ec54189a6b4f9228ac605ab6f21c8d283d8. Check licenses before copying code.

## Findings
- spapple.m and spapple/src/lib.rs obtain profiles via the existing Apple token. The helper installs renewed profiles through misagent; these are not new app installations.
- The Windows companion keeps its signing key in Windows Credential Manager; it does not send that key to the phone.
- SideInstaller's on-device signing and installation flow is a candidate reference. A separate certificate may revoke an existing certificate, so certificate creation and revocation must never happen silently.
- A Device Kit is unsigned and contains bundle ID placeholders. The app and SPJitHelper must receive distinct, valid profiles and preserve the currently installed bundle IDs and team. Do not use the main app profile for the helper.
- GitHub Actions artifacts require authenticated download in some cases. An approved prerelease with a pinned digest and explicit version would be a more suitable update source.

## Stages / acceptance gates
1. Offline package validation: verify trusted digest, both bundle IDs and profile identity, version increase, presence of helper and frameworks, safe ZIP paths. No installation, credentials or certificate changes.
2. On-device read-only preflight: show installed app and helper IDs, team, expiration and available storage. Verify pairing and installation-service availability without changing app or profiles.
3. Investigate local certificate/key generation and signing in an isolated test bundle. Review dependencies and licenses. The private key remains in device-local Keychain, never in repository, logs or network requests. Existing certificates must not be revoked automatically. Obtain distinct profiles; preserve entitlements supported by the account.
4. Sign and validate a test package; test installation and relaunch of a disposable app with a helper, plus preservation of a test file and Keychain item after a version upgrade. No modifications to Alpha 2.
5. Only after success, integrate a user-confirmed updater and test on real hardware. Download over Wi-Fi, verify pinned digest and version, validate signed identity, preserve data via installation in place. Do not uninstall, do not purge game files. Explicit errors and Windows Companion recovery procedure.
6. Production release requires confirmation on iPhone: same app identity, retained game data and Battle.net session, JIT helper working, renewal working, no duplicate app.

## Status
Research and offline validation only. No on-device signer or installer has been implemented or tested. Do not distribute this branch as a working self-updater. Keep the known working Alpha 2 available. For game updates, continue using the original game update mechanism; it does not update Slashplayed itself.
