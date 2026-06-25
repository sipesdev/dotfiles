import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth

// Bluetooth: power toggle + expandable, scrollable device list (named devices
// only). Click to connect / disconnect / pair.
ColumnLayout {
    id: sec
    spacing: 4
    property bool expanded: false
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property int maxListH: Math.round((Screen.height > 0 ? Screen.height : 1000) * 0.5)

    function toggleRadio() { if (adapter) adapter.enabled = !adapter.enabled; }
    function expand() {
        sec.expanded = !sec.expanded;
        if (adapter) adapter.discovering = sec.expanded;
    }
    function tapDevice(d) {
        if (d.connected) d.disconnect();
        else if (d.paired || d.bonded) d.connect();
        else d.pair();
    }
    function named(d) {
        var n = d.name;
        if (!n || n.length === 0) return false;
        if (n === d.address) return false;
        // hide raw MAC-style names (XX:XX:XX:XX:XX:XX)
        return !/^([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}$/.test(n);
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
                text: Theme.btGlyph(sec.adapter ? sec.adapter.enabled : false, false)
                color: (sec.adapter && sec.adapter.enabled) ? Theme.accent : Theme.dim
                font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize + 3
            }
            Text {
                Layout.fillWidth: true
                text: !sec.adapter ? "Bluetooth unavailable"
                    : sec.adapter.enabled ? "Bluetooth" : "Bluetooth off"
                color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize
            }
            Text {
                visible: sec.adapter && sec.adapter.enabled
                text: sec.expanded ? "▾" : "▸"
                color: Theme.dim; font.pixelSize: Theme.fontSize
            }
            Rectangle {
                Layout.preferredWidth: 40; Layout.preferredHeight: 22; radius: 11
                visible: sec.adapter !== null
                color: (sec.adapter && sec.adapter.enabled) ? Theme.accent : Theme.elevated
                Behavior on color { ColorAnimation { duration: 120 } }
                Rectangle {
                    width: 18; height: 18; radius: 9; color: Theme.bright
                    anchors.verticalCenter: parent.verticalCenter
                    x: (sec.adapter && sec.adapter.enabled) ? parent.width - width - 2 : 2
                    Behavior on x { NumberAnimation { duration: 120 } }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sec.toggleRadio() }
            }
        }
        MouseArea {
            anchors.fill: parent; anchors.rightMargin: 52
            enabled: sec.adapter && sec.adapter.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: sec.expand()
        }
        MouseArea { id: hov; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
    }

    // ── Device list (named only, scrollable, capped) ─────────────────
    Flickable {
        id: flick
        Layout.fillWidth: true
        visible: sec.expanded && sec.adapter && sec.adapter.enabled
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
                model: sec.adapter ? sec.adapter.devices : null
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    visible: sec.named(modelData)
                    implicitHeight: visible ? 30 : 0
                    radius: Theme.radius
                    color: dm.containsMouse ? Theme.elevated : "transparent"
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6
                        Text { Layout.fillWidth: true; text: modelData.name; elide: Text.ElideRight
                            color: modelData.connected ? Theme.accent : Theme.text
                            font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize }
                        Text {
                            text: modelData.connected ? "connected"
                                : (modelData.pairing ? "pairing…"
                                : ((modelData.paired || modelData.bonded) ? "paired" : ""))
                            color: Theme.dim; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 2
                        }
                    }
                    MouseArea { id: dm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: sec.tapDevice(modelData) }
                }
            }
        }
    }
}
