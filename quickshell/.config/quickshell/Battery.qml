import QtQuick
import Quickshell.Services.UPower

// Battery: real percentage, charge state, low-warning. Click → time popout.
Rectangle {
    id: root
    signal clicked()

    readonly property var dev: UPower.displayDevice
    readonly property real raw: dev ? dev.percentage : 0
    // Quickshell reports percentage as 0..1 — normalize to whole percent.
    readonly property int pct: Theme.dispPct(Math.round(raw > 1 ? raw : raw * 100))
    readonly property bool pluggedIn: !UPower.onBattery
    readonly property bool charging: dev ? dev.state === 1 : false   // 1 = Charging
    readonly property bool low: pct <= 10

    implicitWidth: rowi.implicitWidth + 2 * Theme.pad
    implicitHeight: 26
    radius: Theme.radius
    color: ma.containsMouse ? Theme.elevated : "transparent"
    Behavior on color { ColorAnimation { duration: 120 } }

    Row {
        id: rowi
        anchors.centerIn: parent
        spacing: 5

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Theme.batteryGlyph(root.pct, root.charging)
            color: (root.charging || root.pluggedIn) ? Theme.accent2
                 : (root.low ? Theme.danger : Theme.text)
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 4
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.pct + "%"
            color: root.low ? Theme.danger : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
