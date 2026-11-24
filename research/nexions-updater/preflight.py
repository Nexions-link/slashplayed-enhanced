#!/usr/bin/env python3
"""Read-only preflight for the unsigned iOS Device Kit. No signing or install."""
import argparse
import hashlib
import json
import plistlib
import re
import stat
import zipfile
from pathlib import Path, PurePosixPath

def check(ok, message):
    if not ok:
        raise ValueError(message)

def validate(path, expected_sha, installed_build, allow_current=False):
    with Path(path).open("rb") as f:
        actual = hashlib.file_digest(f, "sha256").hexdigest()
    check(re.fullmatch(r"[0-9a-fA-F]{64}", expected_sha) and actual == expected_sha.lower(), "SHA-256 mismatch")
    with zipfile.ZipFile(path) as z:
        names = set()
        total = 0
        for item in z.infolist():
            name = item.filename
            p = PurePosixPath(name)
            check(name not in names and not p.is_absolute() and ".." not in p.parts and "\\" not in name and ":" not in name, "Unsafe or duplicate ZIP entry")
            check(not stat.S_ISLNK(item.external_attr >> 16), "Symlink not allowed")
            names.add(name)
            total += item.file_size
        check(total <= 512 * 1024 * 1024, "Unexpected expanded size")
        check(z.testzip() is None, "Invalid ZIP CRC")
        app = "ios/Slashplayed.app/"
        helper = app + "PlugIns/SPJitHelper.appex/"
        def read_plist(name):
            check(name in names and z.getinfo(name).file_size <= 1024 * 1024, "Missing or oversized plist")
            return plistlib.loads(z.read(name))
        a, h = read_plist(app+"Info.plist"), read_plist(helper+"Info.plist")
        for plist, root, executable in [(a, app, "slashplayed"), (h, helper, "SPJitHelper")]:
            check(plist["CFBundleIdentifier"] == "@BUNDLE_ID@", "Unexpected bundle ID template")
            check(plist["CFBundleExecutable"] == executable and root+executable in names, "Missing executable")
        check(a["CFBundleShortVersionString"] == h["CFBundleShortVersionString"] == json.loads(z.read("kit.json"))["version"], "Version mismatch")
        build = int(a["CFBundleVersion"])
        check(build > installed_build or (allow_current and build == installed_build), "Not a newer build")
        for filename in ("ios/entitlements.plist", "ios/helper-entitlements.plist"):
            ent = read_plist(filename)
            check(ent.get("application-identifier") == "@TEAM@.@BUNDLE_ID@" and ent.get("com.apple.developer.team-identifier") == "@TEAM@" and ent.get("get-task-allow") is True, "Unexpected entitlement template")
        check(any(n.startswith(app+"Frameworks/") and n.endswith(".dylib") for n in names), "Missing frameworks")
        check(app+"addons/SPTouchBars/SPTouchBars.lua" in names, "Missing touch bars")
        return {"version": a["CFBundleShortVersionString"], "build": build, "sha256": actual, "expanded_bytes": total, "status": "unsigned package preflight passed; signing, installation and data preservation NOT tested"}

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("kit")
    parser.add_argument("--sha256", required=True, help="Digest from an independently trusted release manifest")
    parser.add_argument("--installed-build", type=int, required=True)
    parser.add_argument("--allow-current", action="store_true", help="Validate known baseline, never use to authorize update")
    args = parser.parse_args()
    try:
        print(json.dumps(validate(args.kit, args.sha256, args.installed_build, args.allow_current), indent=2))
    except (ValueError, OSError, KeyError, TypeError, zipfile.BadZipFile) as e:
        parser.exit(1, f"Preflight refused: {e}\n")
