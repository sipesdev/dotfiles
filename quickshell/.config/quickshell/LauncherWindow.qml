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

    screen: targetScreen
    visible: Launcher.opened && targetScreen !== null

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    // Exclusive for the whole time the surface is mapped: switching modes while mapped makes
    // Hyprland refocus the surface (see BarDrawer). The default namespace is kept so the
    // quickshell-noanim layer rule applies.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Connections {
        target: Launcher
        function onOpenedChanged() {
            if (Launcher.opened) win.targetScreen = win.resolveScreen();
            else win.targetScreen = null;
        }
        function onQueryChanged() {
            if (field.text !== Launcher.query) field.text = Launcher.query;
            win.selected = 0;
            list.positionViewAtBeginning();
        }
    }

    // A monitor unplugged under the open launcher would leave a surface with no output.
    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (Launcher.opened && win.targetScreen && !win.screenPresent(win.targetScreen))
                Launcher.close();
        }
    }

    onVisibleChanged: {
        if (visible) {
            selected = 0;
            field.forceActiveFocus();
        }
    }

    // ── Rows: the calc row first when there is a result, then the apps ──
    readonly property bool hasCalc: Launcher.calcText !== ""
    readonly property var rows: (hasCalc ? [null] : []).concat(Launcher.apps)
    property int selected: 0

    function activate(i) {
        if (i < 0 || i >= rows.length) return;
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
    }

    Rectangle {
        id: card
        width: win.cardWidth
        height: 2 * win.cardPad + win.fieldHeight + Theme.pad + win.listHeight
        x: Math.round((parent.width - width) / 2)
        y: Math.max(0, Math.round((parent.height - win.fullCardHeight) / 2))
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
            interactive: false
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
                    // positionChanged, not entered: a list appearing under a still cursor must not
                    // steal the selection from the keyboard.
                    onPositionChanged: win.selected = row.index
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
