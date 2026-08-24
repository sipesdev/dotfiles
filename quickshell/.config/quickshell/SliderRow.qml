import QtQuick
import QtQuick.Layouts

// [glyph] [slider]: the glyph is a click target (mute / auto-brightness); the slider emits
// moved(v) and never writes its own value (see BarSlider).
Item {
    id: row
    property string glyph: ""
    property color glyphColor: Theme.text
    property real value: 0
    property color fill: Theme.accent
    property bool sliderEnabled: true
    property alias pressed: slider.pressed
    signal moved(real v)
    signal glyphClicked()

    Layout.fillWidth: true
    implicitHeight: 22

    RowLayout {
        anchors.fill: parent
        spacing: Theme.pad
        Text {
            Layout.preferredWidth: 22
            horizontalAlignment: Text.AlignHCenter
            text: row.glyph
            color: row.glyphColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 2
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: row.glyphClicked()
            }
        }
        BarSlider {
            id: slider
            Layout.fillWidth: true
            enabled: row.sliderEnabled
            fill: row.fill
            value: row.value
            onMoved: (v) => row.moved(v)
        }
    }
}
