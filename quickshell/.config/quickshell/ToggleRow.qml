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
        TogglePill {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 22
            on: r.on
            onToggled: r.toggled()
        }
    }

    // Declared last so it sits above the pill's own MouseArea: one click, one toggled().
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: r.toggled()
    }
}
