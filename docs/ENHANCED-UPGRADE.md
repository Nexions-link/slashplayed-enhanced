# Slashplayed Enhanced — iPhone upgrade test (2026-11-24)

## What this build contains

- Pinned official Windows/Linux-capable unsigned game loader from paulstraw/slashplayed commit `c2745ed8143e7233a47a929e8cee0eb7810d4bce`.
- Enhanced native left joystick, right-click button, Ctrl/Shift/Alt/Space keys and multitouch events.
- Enhanced joystick, R and keyboard on/off/size/position preferences in the official Settings -> Touch navigation. The official Battle.net account, Apple token renewal, add-on manager and on-screen keyboard remain.
- Enhanced `SPTouchBars` for WoW Forever, including the in-game touch bar editor via `/sptouch`, ability buttons, utility bar and independent Interact/Target/Map.
- Dynamic resolution guide from Enhanced, while retaining current official resolution scale.

Not included intentionally: older Enhanced signing/patcher code and the old pre-`spguest` game launcher, which require Mac workflows and would break the user's Windows installation. Enhanced's Bagnon auto-installer is not copied: it conflicts with existing Baganator setups.

## Critical before trying SideStore

**A successful unsigned IPA build is not proof that SideStore can replace an existing Windows Companion installation.**

- Windows Companion uses `<Apple developer Team ID>.slashplayed` by default, with a helper bundle `<Team ID>.slashplayed.helper`. The user's actual ID is **not known by CI**.
- Build workflow has an optional manual `bundle_id` input. Its `slashplayed` default is only a generic diagnostic and **cannot be assumed to match the installed app**.
- SideStore may append `.<Team ID>` by default, or strip/update entitlements; disable the appended suffix if using custom App ID and ensure the FINAL identifiers match the installed exact bundle IDs for the app and SPJitHelper extension.
- Use the SAME Apple developer team as the Companion used.
- iOS may reject replacement if the application-identifier signing entitlement differs. If SideStore proposes a second app or errors, STOP; do not delete the working app.
- An already installed app's `Library/sppairing.plist` is only preserved if it is updated in place with its container intact. No public build includes or can generate this confidential iPhone-specific pairing file.
- Two apps with separate Bundle IDs cannot transfer the pairing file through the iOS Files app.
- SideStore extension signing and the JIT helper must both work on the device; this has not been validated for this build.

## User test (only after inspecting final signed identifiers)

1. Keep the working Slashplayed. Back up any accessible WoW preferences and add-on SavedVariables in the Files app.
2. Verify that SideStore is signed into the **same Apple Team** as Windows Companion. Determine the existing app's exact Bundle ID first; if unknown, do not attempt an in-place replacement.
3. In SideStore's customization settings (when available), set exact app ID `<Team ID>.slashplayed`, disable automatic team-ID suffix, and preserve helper extension `<Team ID>.slashplayed.helper`. Confirm the final IDs before installation.
4. Sideload the enhanced IPA over the original; don't delete it and don't select an alternative Bundle ID/clone.
5. Open Slashplayed, verify installed WoW and current pairing survive; turn on LocalDevVPN as before. Verify JIT, world entry, chat and concurrent joystick + jump.
6. In Settings -> Touch, verify control preferences; in WoW run `/sptouch`. If the application does not start or says "not paired", stop and use Windows Companion instead of deleting/reinstalling.

## Windows Companion fallback

Download the **same build's** `slashplayed-device-kit.zip`. Run:

```powershell
.\slashplayed-cli.exe install --kit ".\slashplayed-device-kit.zip"
```

The Companion's default Bundle ID is `<Team ID>.slashplayed` and it writes or preserves `Library/sppairing.plist` and DDI over USB. Do not set a custom ID or delete the working app first. Use the same Apple ID and team. With `--server-client-info` the Companion does **not** deliver the Apple token for in-app profile renewal.

## Signing renewal without PC

- If the app is successfully installed/managed by SideStore (rather than merely Companion), SideStore may be able to refresh its profile every seven days with the same Apple ID/team; this must be validated on the device and does not replace the WoW game files.
- Independently, current official Slashplayed has Settings -> Signing -> Sign In to Apple, which can place an Apple token in the app keychain for automatic self-renewal. It may fail while Apple GSA sign-in is returning HTTP 503, and an older Companion installation with `--server-client-info` has no token initially.
- If neither process works, a Windows Companion run is still necessary. Do not claim an IPA or built-in renewal is proven without the user's physical iPhone test.
