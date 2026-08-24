import QtQuick
import QtQuick.Layouts

// Drawer header: big glyph, title, status line, optional radio toggle on the right.
Item {
    id: hero
    property string glyph: ""
    property color glyphColor: Theme.text
    property string title: ""
    property string status: ""
    property bool toggleVisible: false
    property bool toggleEnabled: true
    property bool on: false
    signal toggled()
    property alias statusOpacity: statusText.opacity

    Layout.fillWidth: true
    implicitHeight: Math.max(col.implicitHeight, 26)

    RowLayout {
        anchors.fill: parent
        spacing: Theme.pad
        Text {
            Layout.preferredWidth: 26
            horizontalAlignment: Text.AlignHCenter
            text: hero.glyph
            color: hero.glyphColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 6
        }
        ColumnLayout {
            id: col
            Layout.fillWidth: true
            spacing: 1
            Text {
                Layout.fillWidth: true
                text: hero.title
                elide: Text.ElideRight
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 1
                font.bold: true
            }
            Text {
                id: statusText
                visible: hero.status !== ""
                Layout.fillWidth: true
                text: hero.status
                elide: Text.ElideRight
                color: Theme.dim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
            }
        }
        TogglePill {
            visible: hero.toggleVisible
            enabled: hero.toggleEnabled
            opacity: enabled ? 1 : 0.45
            Layout.preferredWidth: 40
            Layout.preferredHeight: 22
            on: hero.on
            onToggled: hero.toggled()
        }
    }
}
