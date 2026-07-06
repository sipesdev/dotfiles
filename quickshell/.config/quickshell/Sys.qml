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
        command: [Quickshell.env("HOME") + "/.local/bin/autobrightness"]
        running: sys.autoBrightness          // start/stop the loop with the toggle
    }

    // ── Airplane mode — rfkill is the single source of truth ─────────
    property bool airplaneMode: false

    function toggleAirplane() {
        airplaneProc.command = [Quickshell.env("HOME") + "/.local/bin/airplane-toggle"];
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

    // ── Ethernet (wired) — auto-prefer the wire, park the radio ──────
    // When a wired link comes up (e.g. the eGPU dock's ethernet) we flag it here
    // and turn Wi-Fi off; when it goes away we bring Wi-Fi back (unless airplane
    // mode has the radios locked out). We act only on the transition, so manually
    // re-enabling Wi-Fi while still docked is never undone.
    property bool ethernetConnected: false
    property string ethernetName: ""

    Process {
        id: ethRead
        command: ["sh", "-c",
            "nmcli -t -f TYPE,STATE,CONNECTION device status 2>/dev/null | " +
            "awk -F: '$1==\"ethernet\"&&$2==\"connected\"{print $3; exit}'"]
        stdout: StdioCollector { onStreamFinished: sys.setEthernet(text.trim()) }
    }
    function refreshEthernet() { ethRead.running = true }

    function setEthernet(name) {
        var up = (name !== "");
        sys.ethernetName = name;                       // keep the label current either way
        if (up === sys.ethernetConnected) return;      // no transition → leave Wi-Fi alone
        sys.ethernetConnected = up;
        if (up) sys.setWifiRadio(false);                       // wired → drop the radio
        else if (!sys.airplaneMode) sys.setWifiRadio(true);    // unwired → Wi-Fi back (unless airplane)
    }

    Process { id: wifiRadioCtl }
    function setWifiRadio(on) {
        wifiRadioCtl.command = ["nmcli", "radio", "wifi", on ? "on" : "off"];
        wifiRadioCtl.running = true;
    }

    // Re-read the wired link on ANY NetworkManager change. `nmcli monitor` emits a
    // line per device/connection state change (mirrors the rfkill watcher above).
    Process {
        id: nmWatch
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: sys.refreshEthernet()
        }
        // Keep it alive if `nmcli monitor` ever exits, same as the rfkill watcher.
        onRunningChanged: if (!running) running = true
    }

    Component.onCompleted: { sys.refresh(); sys.refreshEthernet(); }
}
