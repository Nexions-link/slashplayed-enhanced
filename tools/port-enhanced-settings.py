#!/usr/bin/env python3
"""Port native Enhanced touch preferences onto the *modern* official Slashplayed settings.
Leaves official sign-in, Apple-token renewal, addon browser, and the unsigned game loader untouched.
The original Enhanced SwiftUI sections are copied verbatim to keep their behavior.
"""
from pathlib import Path
import sys

official = Path(sys.argv[1])
enhanced = Path(sys.argv[2])
target = official.read_text()
source = enhanced.read_text()


def section(text, start, end):
    assert text.count(start) == 1, ("missing/duplicate start", start, text.count(start))
    start_ix = text.index(start)
    assert text.count(end, start_ix) >= 1, ("missing end", end)
    return text[start_ix:text.index(end, start_ix)]


def once(old, new):
    global target
    count = target.count(old)
    if count != 1:
        raise AssertionError(f"Unexpected modern settings source; expected exactly 1 of: {old!r}, got {count}")
    target = target.replace(old, new)


# Use the same keys, numeric bounds and user-defaults as Enhanced's native joystick and overlays.
constants = section(source, "// spevent.m's thumb overlay", "private func setChordRightFinger")
once("private func setChordRightFinger", constants + "private func setChordRightFinger")

snapshot = section(source, "    var thumbEnabled = true", "    var games:")
once("    var games: [Game] = []", snapshot + "    var games: [Game] = []")

reload_fields = section(source, "        s.thumbEnabled =", "        s.games =")
once("        s.games = flavors.map { flavor in", reload_fields + "        s.games = flavors.map { flavor in")

once(
    "enum Page: Hashable { case acknowledgements, license(License), addons(String), browse(String) }",
    "enum Page: Hashable { case joystick, rightClick, keyboard, acknowledgements, license(License), addons(String), browse(String) }"
)

# Make the native geometry, per-key toggles and positions editable from the current official sheet.
once(
    "                case .acknowledgements: AcknowledgementsView(settings: settings)",
    """                case .joystick: joystick.navigationTitle("Joystick")
                case .rightClick: rightClickButton.navigationTitle("Right-click Button")
                case .keyboard: keyboard.navigationTitle("Keyboard Buttons")
                case .acknowledgements: AcknowledgementsView(settings: settings)"""
)

controls = """            Section("Enhanced On-screen Controls") {
                NavigationLink("Joystick · size and position", value: Page.joystick)
                NavigationLink("Right-click R · size and position", value: Page.rightClick)
                NavigationLink("Keyboard buttons · Ctrl / Shift / Alt / Space", value: Page.keyboard)
            }
"""
# Attach Enhanced controls to the touch section; preserve official two/three-finger touch selector.
once(
    "    private var touch: some View {\n        Section {\n",
    "    @ViewBuilder private var touch: some View {\n" + controls + "        Section {\n"
)

# Take actual shipped Enhanced UI (the trio of native control pages) without its obsolete
# Battle.net identity, pre-spguest game updater or settings sidebar.
controls_impl = section(source, "    private var joystick: some View {", "    #endif\n\n    private func game")
controls_impl = controls_impl.replace("private var touch: some View {", "private var rightClickButton: some View {")
# In modern SwiftUI the gameplay helper keeps the same direct default keys.
once(
    "    private func game(_ g: Snapshot.Game) -> some View {",
    controls_impl + "    private func game(_ g: Snapshot.Game) -> some View {"
)

# Add Enhanced's dynamic resolution reference without taking away official display scale.
display_refs = section(source, "    private struct DisplayChoice: Identifiable {", "    #if !os(visionOS)\n    private var joystick: some View")
display_refs = display_refs.replace("    private var display: some View {", "    private var enhancedDisplay: some View {")
once(
    "                    display\n                    #if !os(visionOS)",
    "                    display\n                    enhancedDisplay\n                    #if !os(visionOS)"
)
once(
    "    private func game(_ g: Snapshot.Game) -> some View {",
    display_refs + "    private func game(_ g: Snapshot.Game) -> some View {"
)

assert target.count("private var joystick: some View") == 1
assert target.count("private var keyboard: some View") == 1
assert target.count("private var rightClickButton: some View") == 1
assert target.count('Button("Forget Apple Token"') == 1
assert target.count("NavigationLink(\"Addons\"") == 1
assert target.count("SPGameFirstFrame") == 0
assert target.count("private var enhancedDisplay: some View") == 1
official.write_text(target)
print("Ported Enhanced touch settings, keyboard toggles, geometry, and resolution reference")
print("Preserved official Apple token renewal, add-on manager and official startup flow")
