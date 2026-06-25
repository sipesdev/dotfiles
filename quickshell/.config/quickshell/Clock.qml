import QtQuick
import Quickshell

Text {
    id: clock
    signal clicked()
    property string now: ""

    SystemClock {
        id: sysClock
        precision: SystemClock.Minutes
    }
    function update() {
        clock.now = Qt.formatDateTime(sysClock.date, "ddd d MMM   h:mm AP");
    }
    Component.onCompleted: update()
    Connections {
        target: sysClock
        function onDateChanged() { clock.update() }
    }

    text: now
    color: Theme.text
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    font.bold: true

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: clock.clicked()
    }
}
