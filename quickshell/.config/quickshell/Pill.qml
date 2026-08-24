import QtQuick
import QtQuick.Layouts

// Selectable chip (glyph + label) for exclusive choices: Wi-Fi band, power profile.
Rectangle {
    id: pill
    property string glyph: ""
    property string label: ""
    property bool active: false
    signal clicked()

    // Never narrower than glyph + label + padding: a RowLayout may stretch a pill but
    // must not squeeze its text into the border ("Performance" needs ~94 px of content).
    Layout.fillWidth: true
    Layout.minimumWidth: implicitWidth
    implicitWidth: content.implicitWidth + 2 * Theme.pad
    implicitHeight: 30
    radius: Theme.radius
    color: ma.containsMouse ? Theme.elevated : Theme.bg
    border.width: 1
    border.color: active ? Theme.accent : Theme.elevated
    Behavior on color { ColorAnimation { duration: Theme.animFast } }
    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 6
        Text {
            visible: pill.glyph !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: pill.glyph
            color: pill.active ? Theme.accent : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 2
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: pill.label
            color: pill.active ? Theme.text : Theme.dim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: pill.clicked()
    }
}
