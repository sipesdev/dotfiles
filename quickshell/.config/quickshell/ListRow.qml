import QtQuick
import QtQuick.Layouts

// A 30 px hover row: [glyph] label ... detail trailing. Device and network lists.
Rectangle {
    id: row
    property string glyph: ""
    property color glyphColor: Theme.text
    property string label: ""
    property color labelColor: Theme.text
    property string detail: ""
    property color detailColor: Theme.dim
    property string trailing: ""
    property color trailingColor: Theme.accent
    signal clicked()

    Layout.fillWidth: true
    implicitHeight: 30
    radius: Theme.radius
    color: ma.containsMouse ? Theme.elevated : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 8
        spacing: 6
        Text {
            visible: row.glyph !== ""
            Layout.preferredWidth: 22
            horizontalAlignment: Text.AlignHCenter
            text: row.glyph
            color: row.glyphColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 2
        }
        Text {
            Layout.fillWidth: true
            text: row.label
            elide: Text.ElideRight
            color: row.labelColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
        Text {
            visible: row.detail !== ""
            text: row.detail
            color: row.detailColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
        }
        Text {
            visible: row.trailing !== ""
            text: row.trailing
            color: row.trailingColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.clicked()
    }
}
