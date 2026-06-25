import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Networking
import Quickshell.Bluetooth

// Right-cluster pill: graded volume / wifi-strength / bluetooth glyphs (MD).
Rectangle {
    id: root
    signal toggled()

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    readonly property var sinkAudio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
    readonly property bool muted: sinkAudio ? sinkAudio.muted : false
    readonly property real vol: sinkAudio ? sinkAudio.volume : 0

    // WiFi: read on/off from NM, and the ACTIVE connection's signal from nmcli
    // (reliable, no scan needed).
    readonly property bool wifiOn: Networking.wifiEnabled
    property bool wifiConnected: false
    property int wifiStrength: 0
    Process {
        id: wifiProbe
        command: ["sh", "-c", "nmcli -t -f IN-USE,SIGNAL dev wifi 2>/dev/null | awk -F: '/^\\*/{print $2; exit}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var s = parseInt(text);
                if (!isNaN(s)) { root.wifiConnected = true; root.wifiStrength = s; }
                else { root.wifiConnected = false; root.wifiStrength = 0; }
            }
        }
    }
    Timer {
        interval: 5000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: wifiProbe.running = true
    }

    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btOn: btAdapter ? btAdapter.enabled : false
    readonly property bool btConnected: {
        var ds = Bluetooth.devices;
        if (ds && ds.values) {
            for (var i = 0; i < ds.values.length; i++)
                if (ds.values[i].connected) return true;
        }
        return false;
    }

    implicitWidth: row.implicitWidth + 2 * Theme.pad
    implicitHeight: 26
    radius: Theme.radius
    color: ma.containsMouse ? Theme.elevated : "transparent"
    Behavior on color { ColorAnimation { duration: 120 } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 10

        Text {
            text: Theme.volGlyph(root.vol, root.muted)
            color: root.muted ? Theme.dim : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 3
        }
        Text {
            text: Theme.wifiGlyph(root.wifiOn, root.wifiConnected, root.wifiStrength)
            color: root.wifiOn ? Theme.text : Theme.dim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 3
        }
        Text {
            text: Theme.btGlyph(root.btOn, root.btConnected)
            color: root.btConnected ? Theme.accent : (root.btOn ? Theme.text : Theme.dim)
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 3
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
