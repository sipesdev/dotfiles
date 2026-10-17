import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick

// The app launcher overlay: a fullscreen click-to-dismiss layer holding a centered card with the
// search field and result rows. State lives in the Launcher singleton; this is only its view.
PanelWindow {
    id: win

    readonly property int cardWidth: 600
    readonly property int cardPad: 2 * Theme.pad
    readonly property int fieldHeight: 40
    readonly property int rowHeight: 48
    readonly property int rowSpacing: 2
    readonly property int maxRows: 8

    // The monitor the launcher opens on, resolved once per open. Held as its own property rather
    // than read back from `screen`, for the same binding-loop reason as NotificationLayer.
    property var targetScreen: null

    function resolveScreen() {
        var screens = Quickshell.screens;
        var name = Hyprland.focusedMonitor?.name;
        for (var i = 0; i < screens.length; i++) {
            if (screens[i].name === name) return screens[i];
        }
        return screens.length > 0 ? screens[0] : null;
    }

    function screenPresent(s) {
        var screens = Quickshell.screens;
        for (var i = 0; i < screens.length; i++) {
            if (screens[i] === s) return true;
        }
        return false;
    }

    // How far the launcher is faded in: 0 = gone, 1 = fully shown. As with BarDrawer's reveal,
    // the surface stays mapped until the fade-out finishes, and onVisibleChanged drops the
    // screen once it has. reveal runs linearly and `fade` applies OutCubic to it, so the fade-out
    // is the fade-in played backwards. Easing reveal itself would ease both directions the same
    // way, leaving the card a faint ghost for the last half of the fade-out (a close that reads
    // slower than the open); switching the easing by direction loses a binding race to the
    // Behavior, which starts with the previous direction's curve.
    property real reveal: Launcher.opened ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: Theme.animMed } }
    readonly property real fade: 1 - Math.pow(1 - reveal, 3)

    screen: targetScreen
    visible: (Launcher.opened || reveal > 0) && targetScreen !== null

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    // No exclusiveZone here: setting one forces exclusionMode back to Normal, which would put the
    // overlay below the bar.
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    // Exclusive only while open, so the keyboard is handed back the moment the fade-out starts:
    // Hyprland refuses focus to a window that maps under an exclusive layer and returns it to the
    // previous window on unmap, so an app quick enough to map mid-fade would open unfocused. The
    // switch makes Hyprland refocus, which is what a close (or a reopen mid-fade) wants. The
    // default namespace is kept so the quickshell-noanim layer rule applies, and Hyprland's own
    // layer fade does not run on top of this one.
    WlrLayershell.keyboardFocus: Launcher.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Connections {
        target: Launcher
        function onOpenedChanged() {
            if (!Launcher.opened) return;
            var s = win.resolveScreen();
            // Reopened mid-fade on the same monitor: the surface never unmapped, so
            // onVisibleChanged will not reset the view. A fade still running on another monitor
            // unmaps there first.
            if (win.visible && s === win.targetScreen) {
                win.resetView();
            } else {
                win.targetScreen = null;
                win.targetScreen = s;
            }
        }
        function onQueryChanged() {
            if (field.text !== Launcher.query) field.text = Launcher.query;
            win.selected = 0;
            list.positionViewAtBeginning();
        }
    }

    // A monitor unplugged under the open (or fading) launcher would leave a surface with no
    // output, so it unmaps at once.
    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (win.targetScreen && !win.screenPresent(win.targetScreen)) {
                win.targetScreen = null;
                Launcher.close();
            }
        }
    }

    onVisibleChanged: {
        if (visible) resetView();
        else targetScreen = null;
    }

    function resetView() {
        selected = 0;
        lastHover = null;
        // open() with an unchanged empty query emits no queryChanged, so reset the scroll here.
        list.positionViewAtBeginning();
        field.forceActiveFocus();
    }

    // ── Rows: the calc row first when there is a result, then the apps ──
    readonly property bool hasCalc: Launcher.calcText !== ""
    readonly property var rows: (hasCalc ? [null] : []).concat(Launcher.apps)
    property int selected: 0
    // Scene position of the last hover event. Rebuilt delegates (every keystroke) and a surface
    // mapping under a parked cursor get a synthetic hover from Qt at the unchanged position, which
    // must not steal the keyboard selection; only a position that differs counts as motion. Null
    // after open, so the first event only records where the pointer is.
    property var lastHover: null

    function activate(i) {
        // The overlay still takes clicks while it fades out, so the second click of a
        // double-click must not launch the app again.
        if (!Launcher.opened || i < 0 || i >= rows.length) return;
        if (hasCalc && i === 0) Launcher.copyCalc();
        else Launcher.launch(rows[i]);
    }

    function moveSelection(delta) {
        if (rows.length === 0) return;
        selected = Math.max(0, Math.min(rows.length - 1, selected + delta));
        list.positionViewAtIndex(selected, ListView.Contain);
    }

    // The card's top edge is where a full-height card would be vertically centered, and fewer
    // rows shrink it from the bottom, so the search field never moves while typing.
    readonly property int listHeight: rows.length === 0
        ? rowHeight
        : Math.min(rows.length, maxRows) * rowHeight + (Math.min(rows.length, maxRows) - 1) * rowSpacing
    readonly property int fullCardHeight: 2 * cardPad + fieldHeight + Theme.pad
        + maxRows * rowHeight + (maxRows - 1) * rowSpacing

    // Click anywhere outside the card to dismiss.
    MouseArea {
        anchors.fill: parent
        onClicked: Launcher.close()
    }

    DrawerShadow {
        x: card.x
        y: card.y
        width: card.width
        height: card.height
        opacity: win.fade
    }

    Rectangle {
        id: card
        width: win.cardWidth
        height: 2 * win.cardPad + win.fieldHeight + Theme.pad + win.listHeight
        x: Math.round((parent.width - width) / 2)
        y: Math.max(0, Math.round((parent.height - win.fullCardHeight) / 2))
        opacity: win.fade
        radius: Theme.radius
        color: Theme.bar
        border.width: 1
        border.color: Theme.elevated

        // The card swallows its own clicks so they do not reach the dismiss area behind it.
        MouseArea { anchors.fill: parent }

        Rectangle {
            id: fieldBox
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: win.cardPad
            height: win.fieldHeight
            radius: Theme.radius
            color: Theme.surface

            TextInput {
                id: field
                anchors.fill: parent
                anchors.leftMargin: Theme.pad + 2
                anchors.rightMargin: Theme.pad + 2
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.text
                selectionColor: Theme.accent
                selectedTextColor: Theme.bg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 3
                clip: true
                selectByMouse: true
                onTextChanged: Launcher.query = text

                Keys.onUpPressed: win.moveSelection(-1)
                Keys.onDownPressed: win.moveSelection(1)
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_PageUp) { win.moveSelection(-10); event.accepted = true; }
                    else if (event.key === Qt.Key_PageDown) { win.moveSelection(10); event.accepted = true; }
                }
                Keys.onReturnPressed: win.activate(win.selected)
                Keys.onEnterPressed: win.activate(win.selected)
                Keys.onEscapePressed: Launcher.close()

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: field.text.length === 0
                    text: "Search"
                    textFormat: Text.PlainText
                    color: Theme.dim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 3
                }
            }
        }

        ListView {
            id: list
            anchors.top: fieldBox.bottom
            anchors.topMargin: Theme.pad
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: win.cardPad
            anchors.rightMargin: win.cardPad
            height: win.listHeight
            visible: win.rows.length > 0
            clip: true
            spacing: win.rowSpacing
            interactive: contentHeight > height
            model: win.rows

            delegate: Item {
                id: row
                required property int index
                required property var modelData
                readonly property bool isCalc: win.hasCalc && index === 0
                readonly property bool isSelected: index === win.selected

                width: list.width
                height: win.rowHeight

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radius
                    color: row.isSelected ? Qt.alpha(Theme.accent, 0.25) : "transparent"
                }

                // App row
                Item {
                    visible: !row.isCalc
                    anchors.fill: parent
                    anchors.leftMargin: Theme.pad
                    anchors.rightMargin: Theme.pad

                    IconImage {
                        id: appIcon
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 32
                        // The webapps' icons are absolute PNG paths, which the theme lookup would reject.
                        source: {
                            if (row.isCalc) return "";
                            var icon = row.modelData.icon || "";
                            return icon.charAt(0) === "/" ? "file://" + icon
                                                          : Quickshell.iconPath(icon, "application-x-executable");
                        }
                    }
                    Column {
                        anchors.left: appIcon.right
                        anchors.leftMargin: Theme.pad
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            width: parent.width
                            text: row.isCalc ? "" : (row.modelData.name || row.modelData.id)
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize + 1
                        }
                        Text {
                            width: parent.width
                            visible: text !== ""
                            text: row.isCalc ? "" : (row.modelData.genericName || "")
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: Theme.dim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 2
                        }
                    }
                }

                // Calc row
                Item {
                    visible: row.isCalc
                    anchors.fill: parent
                    anchors.leftMargin: Theme.pad
                    anchors.rightMargin: Theme.pad

                    Text {
                        id: calcGlyph
                        anchors.verticalCenter: parent.verticalCenter
                        width: 32
                        horizontalAlignment: Text.AlignHCenter
                        text: Theme.iCalculator
                        textFormat: Text.PlainText
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: 24
                    }
                    Column {
                        anchors.left: calcGlyph.right
                        anchors.leftMargin: Theme.pad
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            width: parent.width
                            text: Launcher.calcText
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: Theme.bright
                            font.family: Theme.fontFamily
                            font.pixelSize: 20
                        }
                        Text {
                            width: parent.width
                            text: Launcher.calcExpr
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: Theme.dim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 2
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    // positionChanged, not entered, and only on real motion (see lastHover): a list
                    // appearing under a still cursor must not steal the selection from the keyboard.
                    onPositionChanged: mouse => {
                        var p = mapToItem(null, mouse.x, mouse.y);
                        var last = win.lastHover;
                        win.lastHover = p;
                        if (last && (last.x !== p.x || last.y !== p.y)) win.selected = row.index;
                    }
                    onClicked: win.activate(row.index)
                }
            }
        }

        Text {
            anchors.top: fieldBox.bottom
            anchors.topMargin: Theme.pad
            anchors.left: parent.left
            anchors.right: parent.right
            height: win.rowHeight
            visible: win.rows.length === 0
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: "No Results"
            textFormat: Text.PlainText
            color: Theme.dim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 1
        }
    }
}
