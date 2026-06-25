import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: center
    property bool shown: false
    // Stay mapped while shown OR while the fade-out is still playing, so the
    // layer surface only unmaps once the card has finished fading to 0. (The
    // window color is transparent, so the card's opacity is what fades.)
    visible: shown || card.opacity > 0

    anchors { top: true; right: true }
    margins.top: Theme.gap
    margins.right: Theme.gap
    implicitWidth: 360
    implicitHeight: card.implicitHeight
    color: "transparent"
    exclusiveZone: 0

    // Dismiss when the user clicks outside the popout.
    HyprlandFocusGrab {
        windows: [center]
        active: center.shown
        onCleared: center.shown = false
    }

    onShownChanged: if (shown) {
        brightRead.running = true;
        Networking.scannerEnabled = true;
        refreshWifi();
    }

    // ── Audio (Pipewire) ─────────────────────────────────────────────
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var sinkAudio: sink ? sink.audio : null

    // Optimistic volume the slider displays. The live Pipewire value round-trips
    // asynchronously, which made the slider's glide fire only every other click;
    // driving it from a local value we set synchronously on input (exactly like
    // the brightness row) makes the animation deterministic. External changes
    // (media keys) are mirrored back in via Component.onCompleted / the handlers.
    property real volumeLevel: 0
    Component.onCompleted: if (sinkAudio) volumeLevel = sinkAudio.volume
    onSinkAudioChanged: if (sinkAudio) volumeLevel = sinkAudio.volume
    Connections {
        target: center.sinkAudio
        function onVolumeChanged() { center.volumeLevel = center.sinkAudio.volume; }
    }

    // ── Brightness (brightnessctl) ───────────────────────────────────
    property int brightness: 50
    Process {
        id: brightRead
        command: ["sh", "-c", "brightnessctl -m | cut -d, -f4 | tr -d '%\\n'"]
        stdout: StdioCollector {
            onStreamFinished: { var n = parseInt(text); if (!isNaN(n)) center.brightness = n }
        }
    }
    Process { id: brightSet }
    function setBrightness(pct) {
        center.brightness = pct;
        brightSet.command = ["brightnessctl", "set", pct + "%"];
        brightSet.running = true;
    }
    // Re-read brightness whenever auto-brightness toggles, so the slider snaps to
    // the real value the moment it's turned on or off...
    Connections {
        target: Sys
        function onAutoBrightnessChanged() { brightRead.running = true }
    }
    // ...and keep the slider synced while the panel is open, so hardware
    // brightness-key presses (and auto-brightness) are reflected live. The backlight
    // exposes no reliable change signal for file-watching, so poll. Paused while the
    // user is dragging the slider, so a stale read-back can't fight the input.
    Timer {
        interval: 300; repeat: true
        running: center.shown && !brightSlider.pressed
        onTriggered: brightRead.running = true
    }

    // WiFi radio via nmcli (clears rfkill soft-block reliably, both directions).
    Process { id: wifiCtl }
    function setWifi(on) {
        wifiCtl.command = ["nmcli", "radio", "wifi", on ? "on" : "off"];
        wifiCtl.running = true;
    }

    // ── WiFi (NetworkManager) ────────────────────────────────────────
    property string wifiSsid: ""
    function refreshWifi() {
        var s = "";
        var nets = Networking.networks;
        if (nets && nets.values) {
            for (var i = 0; i < nets.values.length; i++) {
                if (nets.values[i].connected) { s = nets.values[i].name; break; }
            }
        }
        center.wifiSsid = s;
    }
    Connections {
        target: Networking
        function onWifiEnabledChanged() { center.refreshWifi() }
    }

    // ── Bluetooth (BlueZ) ────────────────────────────────────────────
    readonly property var btAdapter: Bluetooth.defaultAdapter
    function btConnectedName() {
        var ds = Bluetooth.devices;
        if (ds && ds.values) {
            for (var i = 0; i < ds.values.length; i++) {
                if (ds.values[i].connected) return ds.values[i].name;
            }
        }
        return "";
    }

    Rectangle {
        id: card
        width: parent.width
        implicitHeight: col.implicitHeight + 2 * Theme.pad
        radius: Theme.radius
        color: Theme.surface
        border.color: Theme.elevated
        border.width: 1

        // Fade the popout in on open and out on close.
        opacity: center.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animMed; easing.type: Easing.InOutQuad } }

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: Theme.pad
            spacing: Theme.pad

            Text {
                text: "Quick Settings"
                color: Theme.dim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
            }

            // ── Volume ───────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.pad
                Text {
                    Layout.preferredWidth: 22
                    horizontalAlignment: Text.AlignHCenter
                    text: Theme.volGlyph(center.sinkAudio ? center.sinkAudio.volume : 0,
                                         center.sinkAudio ? center.sinkAudio.muted : false)
                    color: center.sinkAudio && center.sinkAudio.muted ? Theme.dim : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 2
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (center.sinkAudio) center.sinkAudio.muted = !center.sinkAudio.muted
                    }
                }
                BarSlider {
                    Layout.fillWidth: true
                    enabled: !(center.sinkAudio && center.sinkAudio.muted)
                    value: center.volumeLevel
                    onMoved: (v) => {
                        center.volumeLevel = v;                             // optimistic, synchronous → deterministic glide
                        if (center.sinkAudio) center.sinkAudio.volume = v;  // apply to Pipewire (async)
                    }
                }
                Text {
                    Layout.preferredWidth: 38
                    horizontalAlignment: Text.AlignRight
                    text: Math.round(center.volumeLevel * 100) + "%"
                    color: Theme.dim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                }
            }

            // ── Brightness ───────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.pad
                Text {
                    Layout.preferredWidth: 22
                    horizontalAlignment: Text.AlignHCenter
                    text: Theme.iSun
                    color: Sys.autoBrightness ? Theme.accent : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 2
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Sys.autoBrightness = !Sys.autoBrightness
                    }
                }
                BarSlider {
                    id: brightSlider
                    Layout.fillWidth: true
                    enabled: !Sys.autoBrightness
                    fill: Theme.accent2
                    value: center.brightness / 100
                    onMoved: (v) => center.setBrightness(Math.max(1, Math.round(v * 100)))
                }
                Text {
                    Layout.preferredWidth: 38
                    horizontalAlignment: Text.AlignRight
                    text: center.brightness + "%"
                    color: Theme.dim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.elevated }

            // ── WiFi (toggle + network picker) — locked out in airplane mode ──
            WifiSection {
                Layout.fillWidth: true
                enabled: !Sys.airplaneMode
                opacity: Sys.airplaneMode ? 0.45 : 1
            }

            // ── Bluetooth (toggle + device picker) — locked out in airplane mode ──
            BtSection {
                Layout.fillWidth: true
                enabled: !Sys.airplaneMode
                opacity: Sys.airplaneMode ? 0.45 : 1
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.elevated }

            // ── Power / session row ──────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.gap
                PowerBtn { glyph: Theme.iLock;    cmd: ["loginctl", "lock-session"] }
                PowerBtn { glyph: Theme.iSuspend; cmd: ["systemctl", "suspend"] }
                PowerBtn {
                    glyph:  Theme.iAirplane
                    active: Sys.airplaneMode
                    action: () => Sys.toggleAirplane()
                }
                PowerBtn { glyph: Theme.iReboot;  cmd: ["systemctl", "reboot"] }
                PowerBtn { glyph: Theme.iPower;   cmd: ["systemctl", "poweroff"]; danger: true }
            }
        }
    }
}
