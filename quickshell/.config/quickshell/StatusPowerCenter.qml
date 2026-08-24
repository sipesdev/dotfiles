import Quickshell.Services.Pipewire
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// Interim: the old quick-settings content on the shared drawer shell (retired in Task 11).
BarDrawer {
    id: center
    contentWidth: 360

    onShownChanged: if (shown) brightRead.running = true

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

    // ── Ethernet (wired) — status only; NM handles it, Wi-Fi auto-off ──
    RowLayout {
        Layout.fillWidth: true
        visible: Sys.ethernetConnected
        spacing: Theme.pad
        Text {
            Layout.preferredWidth: 22
            horizontalAlignment: Text.AlignHCenter
            text: Theme.iEthernet
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 2
        }
        Text {
            Layout.fillWidth: true
            text: "Ethernet"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
        Text {
            text: Sys.ethernetName
            color: Theme.dim
            elide: Text.ElideRight
            Layout.maximumWidth: 160
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
        }
    }

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
