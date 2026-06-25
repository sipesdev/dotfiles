import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: pop
    property bool shown: false
    // Stay mapped while shown OR while the fade-out is still playing, so the
    // layer surface only unmaps once the card has finished fading to 0. (The
    // window color is transparent, so the card's opacity is what fades.)
    visible: shown || card.opacity > 0

    anchors { top: true; right: true }
    margins.top: Theme.gap
    margins.right: Theme.gap
    implicitWidth: 240
    implicitHeight: card.implicitHeight
    color: "transparent"
    exclusiveZone: 0

    HyprlandFocusGrab {
        windows: [pop]
        active: pop.shown
        onCleared: pop.shown = false
    }

    readonly property var dev: UPower.displayDevice
    readonly property real raw: dev ? dev.percentage : 0
    readonly property int pct: Theme.dispPct(Math.round(raw > 1 ? raw : raw * 100))
    readonly property bool charging: dev ? dev.state === 1 : false
    readonly property bool pluggedIn: !UPower.onBattery

    function fmt(sec) {
        if (!sec || sec <= 0) return "—";
        var h = Math.floor(sec / 3600);
        var m = Math.floor((sec % 3600) / 60);
        return (h > 0 ? h + "h " : "") + m + "m";
    }

    Rectangle {
        id: card
        width: parent.width
        implicitHeight: colp.implicitHeight + 2 * Theme.pad
        radius: Theme.radius
        color: Theme.surface
        border.color: Theme.elevated
        border.width: 1

        // Fade the popout in on open and out on close.
        opacity: pop.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animMed; easing.type: Easing.InOutQuad } }

        ColumnLayout {
            id: colp
            anchors.fill: parent
            anchors.margins: Theme.pad
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: Theme.batteryGlyph(pop.pct, pop.charging)
                    color: pop.charging || pop.pluggedIn ? Theme.accent2 : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 4
                }
                Text {
                    Layout.fillWidth: true
                    text: "Battery  " + pop.pct + "%"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 1
                    font.bold: true
                }
            }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Theme.dim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
                text: {
                    if (pop.charging)
                        return "Charging — " + pop.fmt(pop.dev ? pop.dev.timeToFull : 0) + " until full";
                    if (pop.pluggedIn)
                        return "Plugged in · not charging";
                    return pop.fmt(pop.dev ? pop.dev.timeToEmpty : 0) + " remaining";
                }
            }
        }
    }
}
