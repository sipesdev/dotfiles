import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: pop
    property bool shown: false
    readonly property int contentWidth: 240

    // How far the card is out of the bar: 0 = fully behind it, 1 = flush against it. The
    // slide animates THIS rather than the card's y directly. Binding y to `shown ? 0 : -height`
    // instead makes the Behavior fire on any height change, including one that happens while
    // the popout is CLOSED -- here, the status line rewrapping when the charger goes in or out.
    // y would then animate from -oldHeight to -newHeight, and for those 160ms the surface maps
    // and flashes a strip of card out from under the bar.
    property real reveal: shown ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }

    // Stay mapped while shown OR while the slide-out is still in flight, so the
    // layer surface only unmaps once the card is fully hidden behind the bar again.
    visible: shown || reveal > 0

    // margins.top: 0 welds the surface to the bar. A top-anchored panel with exclusiveZone 0
    // is placed below the bar's exclusive zone, so the surface top sits at the bar's bottom
    // edge. The window spans to the screen edge and is padded on the left and bottom so the
    // drop shadow has room; the card keeps its gap from the edge via its own rightMargin.
    anchors { top: true; right: true }
    margins.top: 0
    margins.right: 0
    implicitWidth: contentWidth + Theme.gap + Theme.shadowPad
    implicitHeight: card.implicitHeight + Theme.shadowPad
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

    // Drop shadow, cast from the card's shape only, tracking the card as it slides.
    DrawerShadow {
        width: pop.contentWidth
        height: card.implicitHeight
        anchors.right: parent.right
        anchors.rightMargin: Theme.gap
        y: card.y
        topLeftRadius:  0
        topRightRadius: 0
    }

    Rectangle {
        id: card
        width: pop.contentWidth
        anchors.right: parent.right
        anchors.rightMargin: Theme.gap
        implicitHeight: colp.implicitHeight + 2 * Theme.pad
        // Square top corners weld the card to the bar; only the bottom is rounded.
        topLeftRadius:     0
        topRightRadius:    0
        bottomLeftRadius:  Theme.radius
        bottomRightRadius: Theme.radius
        // Bar material sliding out of the bar: no border, matching the notifications.
        color: Theme.bar

        // Slide the popout out of the bar on open and back behind it on close. At reveal 0
        // the card sits entirely above the surface's top edge, so the layer surface clips it
        // and it reads as hiding behind the bar. Deriving y from `reveal` (which is what
        // animates) rather than animating y itself keeps a height change while closed an
        // instant, silent reposition -- see the note on `reveal`.
        y: -height * (1 - pop.reveal)

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
