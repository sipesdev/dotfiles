import QtQuick
import Quickshell.Hyprland

// Workspace strip: the focused workspace is an orange dot, every other existing
// workspace is its number (10 renders as 0). Only workspaces Hyprland reports are
// shown -- no fixed baseline -- and special workspaces (negative ids) are hidden.
Row {
    id: root
    spacing: Theme.gap

    // Sorted snapshot of the live model. ObjectModel.values notifies on create/destroy,
    // so this re-evaluates as workspaces come and go; Hyprland reports them unsorted.
    readonly property var ordered: {
        var ws = Hyprland.workspaces.values.filter(function (w) { return w.id > 0; });
        ws.sort(function (a, b) { return a.id - b.id; });
        return ws;
    }

    Repeater {
        model: root.ordered

        delegate: Item {
            required property var modelData
            readonly property bool focused: modelData.focused

            anchors.verticalCenter: parent.verticalCenter
            width: Theme.wsSlot
            height: Theme.wsSlot

            // Focused: orange dot. Cross-fades with the digit so the swap reads as one motion.
            Rectangle {
                anchors.centerIn: parent
                width: 10; height: 10; radius: 5
                color: Theme.accent
                opacity: focused ? 1 : 0
                scale: focused ? 1 : 0.4
                Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
                Behavior on scale   { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
            }
            // Unfocused: the workspace number.
            Text {
                anchors.centerIn: parent
                text: modelData.id === 10 ? "0" : String(modelData.id)
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.bold: true
                opacity: focused ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: modelData.activate()
            }
        }
    }
}
