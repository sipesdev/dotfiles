pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Shared session state + the long-running helpers that back it.
// Auto-resolved by filename (like Theme), so any component can read `Sys.*`.
Singleton {
    id: sys

    // ── Auto-brightness (defaults off each session) ──────────────────
    property bool autoBrightness: false
    Process {
        id: autoBrightProc
        command: ["/home/michael/.local/bin/autobrightness"]
        running: sys.autoBrightness          // start/stop the loop with the toggle
    }

    // ── Airplane mode — rfkill is the single source of truth ─────────
    property bool airplaneMode: false

    function toggleAirplane() {
        airplaneProc.command = ["/home/michael/.local/bin/airplane-toggle"];
        airplaneProc.running = true;
    }
    // Refresh after the toggle finishes — covers the edge where no radio actually
    // changed (so the rfkill-event watcher wouldn't otherwise fire).
    Process { id: airplaneProc; onRunningChanged: if (!running) sys.refresh() }

    // airplaneMode := (wifi AND bluetooth both soft-blocked)
    Process {
        id: rfkillRead
        command: ["sh", "-c",
            "w=$(rfkill list wifi | grep -c 'Soft blocked: yes'); " +
            "b=$(rfkill list bluetooth | grep -c 'Soft blocked: yes'); " +
            "[ \"$w\" -ge 1 ] && [ \"$b\" -ge 1 ] && echo on || echo off"]
        stdout: StdioCollector {
            onStreamFinished: sys.airplaneMode = (text.trim() === "on")
        }
    }
    function refresh() { rfkillRead.running = true }

    // Re-read on ANY rfkill change — our button, the hardware key, nmcli, etc.
    Process {
        id: rfkillWatch
        running: true
        command: ["rfkill", "event"]            // emits a line per state change
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: sys.refresh()
        }
        // Quickshell does not auto-restart a Process. Keep this watcher alive so the
        // radio lockout never drifts out of sync if `rfkill event` ever exits.
        onRunningChanged: if (!running) running = true
    }

    Component.onCompleted: sys.refresh()
}
