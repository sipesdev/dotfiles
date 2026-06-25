import QtQuick
import Quickshell.Io

Item {
    id: root
    implicitWidth: 38
    implicitHeight: 28

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: ma.containsMouse ? Theme.elevated : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: Theme.iArch          // Arch Linux logo
            color: Theme.accent
            font.family: Theme.fontFamily
            font.pixelSize: 18
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: launcher.running = true
    }

    Process {
        id: launcher
        command: ["walker"]   // opens via the running gapplication-service
    }
}
