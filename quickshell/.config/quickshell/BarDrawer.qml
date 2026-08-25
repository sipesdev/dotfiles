import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// The popout shell every bar module slides out of the bar. A module is a file of the form
// `BarDrawer { key: ...; contentWidth: ...; <content> }`; its content items land in the
// card's ColumnLayout (non-visual children -- Process, Timer, Connections -- are fine too).
// The owning Bar decides which drawer is open: this one is open exactly while
// `barWindow.openPopout === key`, and the focus grab asks the bar to close it. A drawer never
// writes `shown` itself, so a same-pill click can toggle and another pill can switch.
PanelWindow {
    id: drawer

    required property var barWindow          // the Bar this drawer belongs to
    required property string key             // what Bar.openPopout holds while this drawer is open
    property int contentWidth: 320
    property int spacing: Theme.pad          // gap between the content items
    // The bar pill this drawer belongs to: the card's right edge lines up under it. Null
    // lines the card up with the screen edge. Must be a direct child of one of the bar's
    // Rows (every module pill is) -- see anchorEdge.
    property Item anchorItem: null
    default property alias content: col.data

    // Keyboard: None by default (the bar is mouse-driven). A drawer with a text field sets
    // wantsKeyboard so Hyprland lets keys through once the focus grab lands on it, and
    // keyboardExclusive while a field is open so a prompt opened by a bar click -- with no
    // click ever landing inside this surface -- still receives typing.
    property bool wantsKeyboard: false
    property bool keyboardExclusive: false
    WlrLayershell.keyboardFocus: !wantsKeyboard ? WlrKeyboardFocus.None
                               : (keyboardExclusive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand)

    readonly property bool shown: barWindow.openPopout === key

    // A layer surface with no screen lands on the compositor's default output; pin it to the
    // bar's monitor so a click on any bar opens the drawer right there (NotificationLayer does
    // the same).
    screen: barWindow.screen

    // How far the card is out of the bar: 0 = fully behind it, 1 = flush against it. The
    // slide animates THIS rather than the card's y directly. Binding y to `shown ? 0 : -height`
    // instead makes the Behavior fire on any height change, including one that happens while
    // the popout is CLOSED -- a status line rewrapping when the charger goes in or out, a
    // list rescanning, a row appearing. y would then animate from -oldHeight to -newHeight,
    // and for those 160ms the surface maps and flashes a strip of card out from under the bar.
    property real reveal: shown ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }

    // Stay mapped while shown OR while the slide-out is still in flight, so the
    // layer surface only unmaps once the card is fully hidden behind the bar again.
    visible: shown || reveal > 0

    // margins.top: 0 welds the surface to the bar. A top-anchored panel with exclusiveZone 0
    // is placed below the bar's exclusive zone, so the surface top sits at the bar's bottom
    // edge. The window is padded on the left and bottom so the drop shadow has room; the
    // card keeps its gap from the window's right edge via its own rightMargin.
    anchors { top: true; right: true }
    margins.top: 0
    margins.right: rightInset
    implicitWidth: contentWidth + Theme.gap + Theme.shadowPad
    implicitHeight: card.implicitHeight + Theme.shadowPad
    color: "transparent"
    exclusiveZone: 0

    // The pill's right edge in bar coordinates. Summed from x's rather than mapToItem() so
    // the binding re-evaluates when the bar's right Row re-lays out (a tray icon appearing
    // shifts every pill left); mapToItem() registers no dependencies and would go stale.
    readonly property real anchorEdge: (anchorItem && anchorItem.parent)
        ? anchorItem.parent.x + anchorItem.x + anchorItem.width
        : barWindow.width - Theme.gap
    // Inset from the screen's right edge that puts the card's right edge under the pill,
    // clamped so the card never runs off either side. 0 for the rightmost pill, which is
    // exactly where the popouts always sat. The quickshell-noanim layer rule keeps a
    // reposition instant.
    readonly property int rightInset: Math.max(0, Math.min(barWindow.width - implicitWidth,
                                               Math.round(barWindow.width - anchorEdge - Theme.gap)))

    // Dismiss when the user clicks outside the popout. The bar is part of the grab so a
    // click on any bar pill never clears it: Hyprland delivers the dismissing click to the
    // surface under the cursor AFTER clearing, so a same-pill click would close and reopen.
    // Bar clicks reach the pills untouched and Bar.togglePopout() decides.
    HyprlandFocusGrab {
        windows: [drawer, drawer.barWindow]
        active: drawer.shown
        onCleared: drawer.barWindow.closePopout(drawer.key)
    }

    // Drop shadow, cast from the card's shape only, tracking the card as it slides.
    DrawerShadow {
        width: drawer.contentWidth
        height: card.implicitHeight
        anchors.right: parent.right
        anchors.rightMargin: Theme.gap
        y: card.y
        topLeftRadius:  0
        topRightRadius: 0
    }

    Rectangle {
        id: card
        width: drawer.contentWidth
        anchors.right: parent.right
        anchors.rightMargin: Theme.gap
        implicitHeight: col.implicitHeight + 2 * Theme.pad
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
        y: -height * (1 - drawer.reveal)

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: Theme.pad
            spacing: drawer.spacing
        }
    }
}
