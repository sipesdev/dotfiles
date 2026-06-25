import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Networking

// WiFi: radio toggle + expandable, scrollable network list (driven by nmcli).
// Clicking a network runs the wifi-connect helper, which shows a GTK (zenity)
// password dialog when needed and notifies on success/failure.
ColumnLayout {
    id: sec
    spacing: 4
    property bool expanded: false
    readonly property int maxListH: Math.round((Screen.height > 0 ? Screen.height : 1000) * 0.5)

    ListModel { id: netModel }

    Process { id: wifiCtl }
    Process { id: rescan; command: ["nmcli", "device", "wifi", "rescan"] }
    Process {
        id: scanProc
        command: ["sh", "-c", "nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID dev wifi 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: sec.parseNets(text) }
    }
    Process { id: connProc }

    Timer { interval: 6000; running: sec.expanded; repeat: true; triggeredOnStart: true; onTriggered: scanProc.running = true }

    function toggleRadio() {
        wifiCtl.command = ["nmcli", "radio", "wifi", Networking.wifiEnabled ? "off" : "on"];
        wifiCtl.running = true;
    }
    function expand() {
        sec.expanded = !sec.expanded;
        if (sec.expanded) { rescan.running = true; scanProc.running = true; }
    }
    function connect(ssid, secured) {
        connProc.command = ["/home/michael/.local/bin/wifi-connect", ssid, secured ? "1" : "0"];
        connProc.running = true;
    }
    function parseNets(out) {
        netModel.clear();
        var lines = out.split("\n");
        var seen = {}, rows = [];
        for (var i = 0; i < lines.length; i++) {
            var ln = lines[i]; if (!ln) continue;
            var i1 = ln.indexOf(":"), i2 = ln.indexOf(":", i1 + 1), i3 = ln.indexOf(":", i2 + 1);
            if (i1 < 0 || i2 < 0 || i3 < 0) continue;
            var inuse = ln.substring(0, i1) === "*";
            var signal = parseInt(ln.substring(i1 + 1, i2)) || 0;
            var secf = ln.substring(i2 + 1, i3);
            var ssid = ln.substring(i3 + 1).replace(/\\:/g, ":");
            if (ssid === "") continue;
            var secured = secf !== "" && secf !== "--";
            if (seen[ssid] !== undefined) {
                if (signal > seen[ssid].signal) seen[ssid].signal = signal;
                continue;
            }
            var o = { ssid: ssid, signal: signal, secured: secured, inuse: inuse };
            seen[ssid] = o; rows.push(o);
        }
        rows.sort(function (a, b) { if (a.inuse !== b.inuse) return a.inuse ? -1 : 1; return b.signal - a.signal; });
        for (var k = 0; k < rows.length; k++) netModel.append(rows[k]);
    }

    // ── Header (hover-highlighted) ───────────────────────────────────
    Item {
        Layout.fillWidth: true
        implicitHeight: 30
        Rectangle {
            anchors.fill: parent
            radius: Theme.radius
            color: hov.containsMouse ? Theme.elevated : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 4
            anchors.rightMargin: 6
            spacing: Theme.pad
            Text {
                Layout.preferredWidth: 22; horizontalAlignment: Text.AlignHCenter
                text: Theme.wifiGlyph(Networking.wifiEnabled, Networking.wifiEnabled, 100)
                color: Networking.wifiEnabled ? Theme.accent : Theme.dim
                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize + 3
            }
            Text {
                Layout.fillWidth: true
                text: Networking.wifiEnabled ? "Wi-Fi" : "Wi-Fi off"
                color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize
            }
            Text {
                visible: Networking.wifiEnabled
                text: sec.expanded ? "▾" : "▸"
                color: Theme.dim; font.pixelSize: Theme.fontSize
            }
            Rectangle {
                Layout.preferredWidth: 40; Layout.preferredHeight: 22; radius: 11
                color: Networking.wifiEnabled ? Theme.accent : Theme.elevated
                Behavior on color { ColorAnimation { duration: 120 } }
                Rectangle {
                    width: 18; height: 18; radius: 9; color: Theme.bright
                    anchors.verticalCenter: parent.verticalCenter
                    x: Networking.wifiEnabled ? parent.width - width - 2 : 2
                    Behavior on x { NumberAnimation { duration: 120 } }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sec.toggleRadio() }
            }
        }
        MouseArea {
            anchors.fill: parent; anchors.rightMargin: 52
            enabled: Networking.wifiEnabled
            cursorShape: Qt.PointingHandCursor
            onClicked: sec.expand()
        }
        MouseArea { id: hov; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
    }

    // ── Network list (scrollable, capped, smooth height) ─────────────
    Flickable {
        id: flick
        Layout.fillWidth: true
        visible: sec.expanded && Networking.wifiEnabled
        implicitHeight: Math.min(listcol.implicitHeight, sec.maxListH)
        contentHeight: listcol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Behavior on implicitHeight { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }

        ColumnLayout {
            id: listcol
            width: flick.width
            spacing: 2

            Repeater {
                model: netModel
                delegate: Rectangle {
                    required property var model
                    Layout.fillWidth: true
                    implicitHeight: 30
                    radius: Theme.radius
                    color: rm.containsMouse ? Theme.elevated : "transparent"
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 8; spacing: 6
                        Text { Layout.preferredWidth: 20; horizontalAlignment: Text.AlignHCenter
                            text: Theme.wifiGlyph(true, true, model.signal); color: Theme.text
                            font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize + 1 }
                        Text { Layout.fillWidth: true; text: model.ssid; elide: Text.ElideRight
                            color: model.inuse ? Theme.accent : Theme.text
                            font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize }
                        Text { visible: model.secured; text: Theme.iLock; color: Theme.dim
                            font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1 }
                        Text { visible: model.inuse; text: "✓"; color: Theme.accent; font.pixelSize: Theme.fontSize }
                    }
                    MouseArea {
                        id: rm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        // helper toggles: connected SSID → disconnect, else connect
                        onClicked: sec.connect(model.ssid, model.secured)
                    }
                }
            }
        }
    }
}
