import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Rectangle {
    id: b
    property string glyph: ""
    property string tip: ""
    property var cmd: []
    property bool danger: false
    property bool active: false       // highlight (orange) when this button is a toggle that's ON
    property var action: null         // optional JS callback; runs instead of cmd when set

    Layout.fillWidth: true
    implicitHeight: 46
    radius: Theme.radius
    color: ma.containsMouse ? (danger ? Theme.danger : Theme.elevated) : Theme.bg
    border.color: Theme.elevated
    border.width: 1
    Behavior on color { ColorAnimation { duration: 100 } }

    Text {
        anchors.centerIn: parent
        text: b.glyph
        color: b.active ? Theme.accent
             : ma.containsMouse && b.danger ? Theme.bright
             : (b.danger ? Theme.danger : Theme.text)
        font.family: Theme.fontFamily
        font.pixelSize: 18
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (b.action) { b.action(); }
            else { proc.command = b.cmd; proc.running = true; }
        }
    }

    Process { id: proc }
}
