pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Volume OSD state: which level is up ("output" or "input") and whether it is showing.
// OsdWindow (one per bar) draws it. Only the volume and mic-mute keybinds raise it, through
// `qs ipc call osd output|input` after their wpctl, so the drawer slider and the pill wheel
// never do. Auto-resolved by filename (like Launcher), so any component can read `Osd.*`.
Singleton {
    id: osd

    property string kind: "output"
    property bool shown: false

    // Every press restarts the countdown: a held key keeps the OSD up, and it goes once the
    // last press is timeout old.
    readonly property int timeout: 1500
    function show(k) { kind = k; shown = true; hideTimer.restart(); }

    Timer {
        id: hideTimer
        interval: osd.timeout
        onTriggered: osd.shown = false
    }

    IpcHandler {
        target: "osd"

        function output(): void { osd.show("output"); }
        function input(): void { osd.show("input"); }
    }
}
