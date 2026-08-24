pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth

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

    // ── Ethernet (wired) — auto-prefer the wire, park the radio ──────
    // When a wired link comes up (e.g. the eGPU dock's ethernet) we flag it here and turn
    // Wi-Fi off; when it goes away we bring Wi-Fi back only if WE parked it, so a radio that
    // was already off (hardware airplane key, switched off by hand) stays off. We act only
    // on the transition, so manually re-enabling Wi-Fi while still docked is never undone.
    property bool ethernetConnected: false
    property string ethernetName: ""
    property bool wifiParkedByWire: false

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
        if (up) { sys.wifiParkedByWire = sys.wifiEnabled; sys.setWifiRadio(false); }   // wired → park the radio
        else if (sys.wifiParkedByWire) { sys.wifiParkedByWire = false; sys.setWifiRadio(true); }   // unwired → unpark
    }

    Process { id: wifiRadioCtl }
    function setWifiRadio(on) {
        wifiRadioCtl.command = ["nmcli", "radio", "wifi", on ? "on" : "off"];
        wifiRadioCtl.running = true;
    }

    // Re-read the wired link on ANY NetworkManager change. `nmcli monitor` emits a
    // line per device/connection state change.
    Process {
        id: nmWatch
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: sys.refreshEthernet()
        }
        // Quickshell does not auto-restart a Process; keep it alive if `nmcli monitor` ever exits.
        onRunningChanged: if (!running) running = true
    }

    // ── Network (Quickshell.Networking, NetworkManager backend) ──────
    // Native device/network objects shared by the bar pill and the Network drawer. Replaces
    // the old 5 s `nmcli` strength poll: signalStrength is live.
    readonly property bool wifiEnabled: Networking.wifiEnabled
    function netDevice(type) {                       // first device of a type, preferring a connected one
        var ds = Networking.devices.values, fallback = null;
        for (var i = 0; i < ds.length; i++) {
            var d = ds[i];
            if (!d || d.type !== type) continue;
            if (d.connected) return d;
            if (!fallback) fallback = d;
        }
        return fallback;
    }
    readonly property var wifiDevice:  netDevice(DeviceType.Wifi)
    readonly property var wiredDevice: netDevice(DeviceType.Wired)
    readonly property var wifiNetwork: {
        var nets = wifiDevice && wifiDevice.networks ? wifiDevice.networks.values : [];
        for (var i = 0; i < nets.length; i++) if (nets[i] && nets[i].connected) return nets[i];
        return null;
    }
    readonly property bool   wifiConnected: wifiNetwork !== null
    readonly property string wifiSsid:      wifiNetwork ? wifiNetwork.name : ""
    readonly property int    wifiStrength:  wifiNetwork ? Math.round(wifiNetwork.signalStrength * 100) : 0

    // ── Bluetooth (BlueZ) — shared by the bar pill and the drawer ────
    // Each device's `connected` read inside the binding is a tracked dependency, so the
    // value flips the moment any device connects or drops.
    readonly property var  btAdapter: Bluetooth.defaultAdapter
    readonly property bool btOn: btAdapter ? btAdapter.enabled : false
    readonly property bool btConnected: {
        var ds = Bluetooth.devices.values;
        for (var i = 0; i < ds.length; i++) if (ds[i] && ds[i].connected) return true;
        return false;
    }

    // Power goes through the rfkill soft block (bluetooth-power), never adapter.enabled: BlueZ
    // does not persist Powered, so an adapter switched off that way is back on after a reboot,
    // while systemd-rfkill restores the block. Explicit direction, not toggle: the switch follows
    // BlueZ's confirmed state, so a second click inside the confirmation window would undo the first.
    Process { id: btPowerProc }
    function setBluetoothPower(on) {
        btPowerProc.command = [Quickshell.env("HOME") + "/.local/bin/bluetooth-power", on ? "on" : "off"];
        btPowerProc.running = true;
    }

    // ── Bluetooth discovery — one scan shared by every monitor's drawer ──
    // BlueZ rejects StartDiscovery while the adapter is still powering up and lets discovery time
    // out on its own, so while any drawer is open keep nudging it back on. The session is held by
    // quickshell's D-Bus connection, so nothing ends it at close: the stop timer is bound to the
    // CONFIRMED state (quickshell only forwards a write that differs from BlueZ's last report, so a
    // stop issued while a start is still unconfirmed would be swallowed), and it is bounded so a
    // scan another client keeps up cannot draw StopDiscovery fire forever. Leaving inquiry running
    // starves A2DP audio on the same controller into stutters.
    property int btDrawersOpen: 0
    property bool btOwesDiscoveryStop: false          // ownership, not state: only stop what we started
    readonly property bool btWantsDiscovery: btDrawersOpen > 0 && btOn
    // A drawer opening onto a scan that is already running adopts it, so its close settles it.
    onBtWantsDiscoveryChanged: if (btWantsDiscovery && btAdapter && btAdapter.discovering) btOwesDiscoveryStop = true
    Timer {
        id: btDiscoveryRetry
        interval: 1000; repeat: true; triggeredOnStart: true
        running: sys.btWantsDiscovery && sys.btAdapter !== null && !sys.btAdapter.discovering
        onTriggered: { sys.btOwesDiscoveryStop = true; sys.btAdapter.discovering = true; }
    }
    Timer {
        id: btDiscoveryStop
        interval: 1000; repeat: true
        property int attempts: 0
        running: !sys.btWantsDiscovery && sys.btOwesDiscoveryStop && sys.btAdapter !== null && sys.btAdapter.discovering === true
        onRunningChanged: if (running) attempts = 0
        onTriggered: {
            attempts += 1;
            if (attempts > 3) { sys.btOwesDiscoveryStop = false; return; }
            sys.btAdapter.discovering = false;
        }
    }
    // The debt is settled the moment BlueZ reports discovery down, whether our stop landed or the
    // session ended another way, so a stale claim never touches a scan another client starts later.
    Connections {
        target: sys.btAdapter
        function onDiscoveringChanged() { if (!sys.btAdapter.discovering) sys.btOwesDiscoveryStop = false; }
    }

    Component.onCompleted: sys.refreshEthernet()
}
