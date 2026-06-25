import QtQuick
import Quickshell.Hyprland

Row {
    id: root
    spacing: Theme.gap

    Repeater {
        model: Hyprland.workspaces

        delegate: Rectangle {
            required property var modelData
            readonly property bool focused: modelData.focused

            anchors.verticalCenter: parent.verticalCenter
            width: focused ? 26 : 12
            height: 10
            radius: 5
            color: focused ? Theme.accent : Theme.selection

            Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 150 } }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: modelData.activate()
            }
        }
    }
}
