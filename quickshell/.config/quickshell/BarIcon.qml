import QtQuick

// A bar pill with one glyph: the module icons in the right cluster. `active` keeps the
// hover fill on while the pill's drawer is open, so the open module reads at a glance.
Rectangle {
    id: root
    property string glyph: ""
    property color glyphColor: Theme.text
    property bool active: false
    signal clicked()

    implicitWidth: label.implicitWidth + 2 * Theme.iconPad
    implicitHeight: Theme.pillHeight
    radius: Theme.radius
    color: (ma.containsMouse || active) ? Theme.elevated : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.glyph
        color: root.glyphColor
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize + 3
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
