# Nexions edition — changelog

This file records changes made in **Slashplayed Enhanced by Nexions**. The inherited [CHANGELOG.md](CHANGELOG.md) documents the original projects; their work is not claimed as Nexions' own. The version label below identifies our build, not an official upstream release.

## [Unreleased]

No new build is published by this documentation change.

Potential future work (not implemented): game data download visibility, storage diagnostics, in-game native control settings, and reliable signature renewal.

## 1.6.2 — 2026-11-24

[Download and release assets](https://github.com/Nexions-link/slashplayed-enhanced/releases/tag/enhanced-upgrade-20261124) · [Successful build](https://github.com/Nexions-link/slashplayed-enhanced/actions/runs/45272938973)

### Nexions changes
- Integrated Enhanced's native touch-control preferences with the modern official Windows-compatible Slashplayed launcher.
- Retained official on-screen keyboard, game loader, pairing/JIT flow, Apple-token renewal and addon manager.
- Made joystick, R, Ctrl, Alt, Shift and Space controls configurable; bundled Enhanced's existing SPTouchBars editor for Forever.
- Packaged a generic sideloadable IPA and a Windows Companion device kit.
- Added configurable bundle identifiers in the build workflow and documented in-place updating.

### Validation and known issues
- Successful CI compilation and IPA structure checks.
- A tester reported a successful SideStore update over a Windows Companion installation, preserving pairing and allowing WoW Forever to launch. This is one device test, not a general compatibility guarantee.
- To update in place, use the same developer team, the exact existing bundle ID, and a separate matching helper profile. Do not delete the working installation.
- SideStore Refresh / Reset Certificate is not confirmed working; the tester encountered certificate and extension-identifier errors. Reinstalling the same IPA in place as a renewal method has not yet been verified.
- Mobile network disconnects and incomplete streamed game resources remain under investigation.

## Touch prototype — 2026-11-23

[Release](https://github.com/Nexions-link/slashplayed-enhanced/releases/tag/touch-prototype-20261123)

- Ported Enhanced joystick, R, Space and SPTouchBars to the current official loader, retaining the modern keyboard.
- Built and packaged the Windows Companion-compatible kit.
- Initial prototype did not include Enhanced's full native control settings.

## Separate addon experiment — WeHavePhonesTouch 0.0.13

[Release](https://github.com/Nexions-link/slashplayed-enhanced/releases/tag/wehavephones-touch-v0.0.13-extracted)

- Packaged the original Lua addon from [ashmerra/wehavephones](https://github.com/ashmerra/wehavephones/tree/v0.0.13), with its license and a reconstructed standalone loader.
- This is not a Nexions-authored addon or a bundled Slashplayed feature. Android-native controls are not included; compatibility with Slashplayed has not been validated.

## Credits

- [Paul Straw / Straw Dynamics and contributors](https://github.com/paulstraw/slashplayed): original Slashplayed, native compatibility layer, launcher and Companion.
- [rollarz and Enhanced contributors](https://github.com/rollarz/slashplayed-enhanced): Enhanced touch input, layout controls, SPTouchBars and related UX.
- Nexions: integration, compatibility port, packaging, and device testing of this derivative.

See [LICENSE](LICENSE) for the retained MIT license. Third-party components retain their own licenses. No Blizzard game files or private device pairing records are included.
