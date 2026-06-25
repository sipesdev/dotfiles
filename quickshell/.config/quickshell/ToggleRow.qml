import QtQuick
import QtQuick.Layouts

// A row: [icon] [label] ……… [toggle pill]. Whole row is clickable.
Item {
    id: r
    property string glyph: ""
    property string label: ""
    property bool on: false
    signal toggled()

    implicitHeight: 28

    RowLayout {
        anchors.fill: parent
        spacing: Theme.pad

        Text {
            Layout.preferredWidth: 22
            horizontalAlignment: Text.AlignHCenter
            text: r.glyph
            color: r.on ? Theme.accent : Theme.dim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 2
        }
        Text {
            Layout.fillWidth: true
            text: r.label
            elide: Text.ElideRight
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
        Rectangle {                       // toggle pill
            Layout.preferredWidth: 40
            Layout.preferredHeight: 22
            radius: 11
            color: r.on ? Theme.accent : Theme.elevated
            Behavior on color { ColorAnimation { duration: 120 } }
            Rectangle {
                width: 18; height: 18; radius: 9
                color: Theme.bright
                anchors.verticalCenter: parent.verticalCenter
                x: r.on ? parent.width - width - 2 : 2
                Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: r.toggled()
    }
}
