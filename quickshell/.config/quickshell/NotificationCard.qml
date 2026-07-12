import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

// One notification. The reveal animates the cell height 0 -> cardHeight with the card
// pinned to the cell's bottom edge, so the card slides down out of the cell's top edge --
// for the top card that edge is the bar (or the screen top under fullscreen), so it
// emerges from behind it, and the cards below are pushed down as the cell grows.
//
// The card lives inside `clipper` so the reveal can clip it, while the drop shadow is cast
// from a plain `silhouette` that sits OUTSIDE the clip. The shadow must come from the
// card's shape only -- sourcing the card's content would make every glyph cast a shadow.
Item {
    id: cell
    required property var modelData
    required property int index                 // 0 == topmost == welded to the bar

    readonly property var record: modelData
    // Actions live on the Notification, which is gone once the app closes it.
    readonly property var actions: record.notif ? record.notif.actions : []

    width: Theme.notifWidth
    // Collapsed cells are skipped by the Column, so a card on its way out leaves no gap.
    visible: implicitHeight > 0

    property bool shown: false
    Component.onCompleted: cell.shown = true    // 0 -> h; Behaviors are inert during init
    implicitHeight: shown ? card.implicitHeight : 0
    Behavior on implicitHeight {
        // ScriptAction, not the NumberAnimation's onFinished: Qt runs a Behavior's
        // animation as a transition job and does not reliably emit finished() from it,
        // which strands the record in the model and leaves the layer surface mapped.
        SequentialAnimation {
            NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic }
            ScriptAction { script: if (!cell.shown) Notifs.remove(cell.record); }
        }
    }

    // The one place a card leaves. The record raises `dismissing` when its countdown ran
    // out, when the app closed it, when the user clicked it, or when it overflowed the
    // stack -- and every card it has, on every monitor, animates out together.
    Connections {
        target: cell.record
        function onDismissingChanged() { if (cell.record.dismissing) cell.shown = false; }
    }

    // Drop shadow, cast from the card's shape only. Outside `clipper` so it is not clipped;
    // the card covers the silhouette, leaving just the blur bleeding past the edges.
    DrawerShadow {
        anchors.fill: parent
        topLeftRadius:  cell.index === 0 ? 0 : Theme.radius
        topRightRadius: cell.index === 0 ? 0 : Theme.radius
    }

    // The card, clipped so it reveals by sliding down out of the cell's top edge.
    Item {
        id: clipper
        anchors.fill: parent
        clip: true

        // Borderless: the card is plain bar material, so it reads as the bar itself sliding
        // down rather than a separate panel. All cards are identical -- urgency changes
        // nothing. The top card welds flush to the bar (square top corners); cards pushed
        // below it round out and float, their corners animating as they move.
        Rectangle {
            id: card
            width: parent.width
            y: parent.height - implicitHeight       // bottom edge tracks the cell's bottom edge
            implicitHeight: colc.implicitHeight + 2 * Theme.pad
            color: Theme.bar

            topLeftRadius:     cell.index === 0 ? 0 : Theme.radius
            topRightRadius:    cell.index === 0 ? 0 : Theme.radius
            bottomLeftRadius:  Theme.radius
            bottomRightRadius: Theme.radius
            Behavior on topLeftRadius  { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }
            Behavior on topRightRadius { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }

            // Click anywhere to dismiss. Declared before the layout so the action buttons,
            // being later siblings, take their own clicks first.
            //
            // Both handlers write to the RECORD rather than to this card. There is one Bar
            // -- and so one of these cards -- per monitor, all repeating over the same
            // shared model, and the countdown lives on the record for that reason (see
            // Notifs). Reporting hover there is what lets the copy under the pointer pause
            // the single countdown; pausing a local one would leave the copies on the other
            // screens free to run out and reap the card being read. Dismissing there makes
            // every copy animate out together.
            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: cell.record.hovered = hover.containsMouse
                onClicked: cell.record.dismissing = true
            }

            ColumnLayout {
                id: colc
                anchors { left: parent.left; right: parent.right; top: parent.top }
                anchors.margins: Theme.pad
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.pad

                    IconImage {
                        visible: source != ""
                        implicitSize: 20
                        asynchronous: true
                        // The app's own image wins; otherwise resolve its icon name against
                        // the icon theme (iconPath returns "" when check is set and it misses).
                        source: cell.record.image !== "" ? cell.record.image
                              : cell.record.appIcon !== "" ? Quickshell.iconPath(cell.record.appIcon, true)
                              : ""
                    }
                    Text {
                        Layout.fillWidth: true
                        text: cell.record.summary
                        color: Theme.bright
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        font.bold: true
                    }
                    Text {
                        Layout.maximumWidth: 90
                        text: cell.record.appName
                        color: Theme.dim
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 3
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: cell.record.body !== ""
                    text: cell.record.body
                    // We advertise bodyMarkupSupported: false, but Text defaults to AutoText
                    // and would still render an app's stray markup. Force it literal.
                    textFormat: Text.PlainText
                    wrapMode: Text.WordWrap
                    maximumLineCount: 6
                    elide: Text.ElideRight
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: cell.actions.length > 0 ? Theme.gap - 4 : 0
                    visible: cell.actions.length > 0
                    spacing: Theme.gap

                    Repeater {
                        model: cell.actions

                        delegate: Rectangle {
                            id: btn
                            required property var modelData

                            Layout.fillWidth: true
                            implicitHeight: 26
                            radius: Theme.radius
                            // Rest colour is surface, not bar: the card body is bar, so a
                            // bar-coloured button would disappear into it.
                            color: bm.containsMouse ? Theme.elevated : Theme.surface
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: btn.modelData.text
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 1
                            }

                            MouseArea {
                                id: bm
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                // The notification can close between paint and click, taking
                                // its actions with it; only invoke while it is still alive.
                                onClicked: {
                                    if (cell.record.notif) btn.modelData.invoke();
                                    cell.record.dismissing = true;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
