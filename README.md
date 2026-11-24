# Slashplayed Enhanced by Nexions

**An unofficial community fork integrating Enhanced touch controls with the modern Slashplayed launcher for iPhone and iPad.**

[Downloads](https://github.com/Nexions-link/slashplayed-enhanced/releases) · [Nexions changelog](NEXIONS_CHANGELOG.md) · [Build sources](https://github.com/Nexions-link/slashplayed-enhanced/tree/feature/official-touch) · [MIT license](LICENSE)

> **Experimental software.** This is an independent derivative, not an official release of Slashplayed, Enhanced, Blizzard or Apple. The original authors' work and license are retained. Blizzard does not support playing WoW this way; compatibility can change with game or iOS updates.

## What Nexions adds

Nexions integrates the existing Enhanced controls with the newer upstream loader, preserving the official keyboard, Windows Companion compatibility and on-device game updates. The original Enhanced touch controls and SPTouchBars are credited to their respective authors below.

- Native joystick, R, Space, Ctrl, Alt and Shift with configurable visibility, size and position.
- Enhanced touch-control settings integrated into the modern official settings screen.
- SPTouchBars for WoW Forever: customizable ability and utility buttons, modifier layers, spell sets, and layout editing with `/sptouch`.
- Official launcher, game download and update flow, and native keyboard retained.
- CI-built IPA plus Windows-compatible device kit for installation and testing.

## Downloads and current status

**[1.6.2 — experimental upgrade candidate](https://github.com/Nexions-link/slashplayed-enhanced/releases/tag/enhanced-upgrade-20261124)**

CI build and IPA structure checks passed. A tester successfully updated a Windows-installed copy using SideStore, retained pairing and launched WoW Forever. This does not guarantee success on every device.

| Capability | Status |
| --- | --- |
| Windows Companion initial setup | Tested with the earlier touch prototype; device kit provided for the current build |
| SideStore in-place update and preserved pairing | Reported working on one iPhone |
| WoW Forever launch | Reported working |
| SideStore Refresh / automatic renewal | Not yet confirmed; certificate and extension-ID errors observed |
| Mobile data / streaming behavior | Under investigation |

## Install or update

For initial setup, see the official [Windows / Linux instructions](https://github.com/paulstraw/slashplayed/blob/main/docs/setup-without-a-mac.md). The release provides a Windows Companion device kit; use the corresponding official companion and its `--kit` option. A plain IPA is not a substitute for the initial pairing.

For an existing working installation, a SideStore update requires the same Apple developer team and matching signed app and helper identifiers:

1. Keep the original installation. Do **not** delete or deactivate it.
2. In SideStore, enable **Customize AppID** and **Customize App Extensions**.
3. Install the release IPA using the exact existing bundle ID. For a default Companion installation it is `<TEAM_ID>.slashplayed`; do not append the team ID again.
4. Keep the extension using **Register App ID for Each Extension**. The matching helper ID is `<TEAM_ID>.slashplayed.helper`.
5. Check that the existing app was updated, then verify WoW and JIT.

If an extra app appears, or the signing operation fails, stop rather than deleting the working app. The app's pairing record lives in its private container. It is not in any public download.

See the [detailed upgrade notes](https://github.com/Nexions-link/slashplayed-enhanced/blob/feature/enhanced-controls-upgrade/docs/ENHANCED-UPGRADE.md). Refresh-based signing renewal remains experimental.

## Source and upstream projects

- [Nexions integration branch](https://github.com/Nexions-link/slashplayed-enhanced/tree/feature/official-touch) — our build workflow and integration tooling.
- [Original Slashplayed — Paul Straw / Straw Dynamics](https://github.com/paulstraw/slashplayed) — original compatibility layer, launcher, Companion, JIT and game update mechanisms.
- [Original Slashplayed Enhanced — rollarz and contributors](https://github.com/rollarz/slashplayed-enhanced) — original touch controls, SPTouchBars, layout editing and Enhanced user experience.
- [Original Enhanced documentation and inherited development history](UPSTREAM-ENHANCED.md).

## License and acknowledgements

This project retains the original [MIT license](LICENSE), Copyright (c) 2026 Straw Dynamics, and upstream attribution. Third-party components retain their own licenses and notices. Nexions claims only its integration and subsequent modifications, not authorship of the original projects.

World of Warcraft and Battle.net are trademarks of Blizzard Entertainment, Inc.; iPhone, iPad, iOS and related names are trademarks of Apple Inc. No Blizzard game binaries, game data, Apple credentials or device pairing records are distributed in our releases. Game content is obtained from Blizzard's services.

For issues involving the Nexions build, use this fork's [issue tracker](https://github.com/Nexions-link/slashplayed-enhanced/issues). Never post passwords, signing keys, pairing records or personal account information.
