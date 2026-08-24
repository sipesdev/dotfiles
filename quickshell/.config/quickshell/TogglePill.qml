import QtQuick

// The bare on/off switch (track + sliding knob). Bind `on` to real state and flip it in
// response to `toggled()` -- the pill never writes its own value.
Rectangle {
    id: pill
    property bool on: false
    signal toggled()

    implicitWidth: 40
    implicitHeight: 22
    radius: height / 2
    color: on ? Theme.accent : Theme.elevated
    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    Rectangle {                       // knob
        width: parent.height - 4; height: width; radius: width / 2
        color: Theme.bright
        anchors.verticalCenter: parent.verticalCenter
        x: pill.on ? parent.width - width - 2 : 2
        Behavior on x { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: pill.toggled()
    }
}
