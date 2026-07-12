import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick

// The notification stack, welded under the bar on the focused monitor. Declared as a
// child of Bar so there is one per screen, exactly like the popouts.
PanelWindow {
    id: layer

    // The ShellScreen this layer belongs to, handed down by Bar. Held as its own property
    // rather than comparing against the window's own `screen`: a layer surface re-resolves
    // `screen` as it maps and unmaps, and `visible` below depends on the comparison, so
    // reading `screen` back here closes a loop -- QML reports a binding loop on every
    // show and hide.
    required property var barScreen
    screen: barScreen

    // HyprlandMonitor has no `screen` property, so monitors are matched by name.
    // focusedMonitor is null for a beat at startup (qs-start waits for the outputs to
    // register, not for focus); `?.` hides the layer for that beat rather than throwing.
    readonly property bool focusedHere: Hyprland.focusedMonitor?.name === barScreen.name

    // Hyprland does not draw the Top layer over a fullscreen window -- that is why a
    // fullscreen app covers the bar -- and it would cover these with it. Under
    // fullscreen we move to the Overlay layer, which is always drawn, and stop
    // respecting the bar's exclusive zone, which slides the surface up to y = 0. The
    // cards need no changes at all: they always emerge from the surface's top edge,
    // which is now the top of the screen instead of the bottom of the bar.
    readonly property bool fullscreen: Hyprland.focusedMonitor?.activeWorkspace?.hasFullscreen ?? false

    // The window spans to the screen edge and is padded on the left and bottom so the cards'
    // drop shadows have room to render (a layer surface clips anything past its own bounds).
    // The stack keeps its gap from the screen edge via its own rightMargin, so cards sit
    // exactly where they did before the padding was added.
    anchors { top: true; right: true }
    margins.top: 0
    margins.right: 0
    implicitWidth: Theme.notifWidth + Theme.gap + Theme.shadowPad
    implicitHeight: stack.implicitHeight + Theme.shadowPad
    color: "transparent"

    // Reserve nothing either way. Normal still respects the bar's zone (surface lands
    // at the bar's bottom edge); Ignore does not (surface lands at the screen's top).
    exclusiveZone: 0
    exclusionMode: fullscreen ? ExclusionMode.Ignore : ExclusionMode.Normal
    WlrLayershell.layer: fullscreen ? WlrLayer.Overlay : WlrLayer.Top

    // Held means a popout is covering this spot; the cards stay alive with their
    // countdowns frozen, they just stop being drawn until it closes.
    visible: focusedHere && !Notifs.held && Notifs.model.values.length > 0

    Column {
        id: stack
        anchors { top: parent.top; right: parent.right; rightMargin: Theme.gap }
        width: Theme.notifWidth
        spacing: Theme.gap

        Repeater {
            model: Notifs.model
            delegate: NotificationCard {}
        }
    }
}
