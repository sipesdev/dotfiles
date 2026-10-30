import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// The volume OSD: the audio drawer's OUTPUT or INPUT section on its own, sliding out of the
// bar under the audio pill while Osd.shown. Display only -- the empty mask makes the surface
// click-through and it never takes the keyboard, so it cannot steal a click or focus from the
// window under it. Declared in Bar, one per screen, and shown on the focused monitor only, as
// NotificationLayer is. The card and its slide are BarDrawer's; see the notes there.
PanelWindow {
    id: osd

    required property var barWindow          // the Bar this OSD belongs to
    property Item anchorItem: null           // the audio pill; the card's right edge lines up under it
    property int contentWidth: 340           // the audio drawer's width

    screen: barWindow.screen

    // HyprlandMonitor has no `screen`, so monitors are matched by name; focusedMonitor is null
    // for a beat at startup, which `?.` turns into "not here".
    readonly property bool focusedHere: Hyprland.focusedMonitor?.name === barWindow.screen.name
    // Under a fullscreen window the bar is not drawn, so the OSD moves to the Overlay layer and
    // ignores the bar's zone, sliding out of the screen's top edge instead (as NotificationLayer).
    readonly property bool fullscreen: Hyprland.focusedMonitor?.activeWorkspace?.hasFullscreen ?? false

    // An open audio drawer already shows the same slider moving, so the OSD stays down under it.
    readonly property bool shown: Osd.shown && focusedHere && barWindow.openPopout !== "audio"

    property real reveal: shown ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }
    visible: shown || reveal > 0

    anchors { top: true; right: true }
    margins.top: 0
    margins.right: rightInset
    implicitWidth: contentWidth + Theme.gap + Theme.shadowPad
    implicitHeight: card.implicitHeight + Theme.shadowPad
    color: "transparent"
    exclusiveZone: 0
    exclusionMode: fullscreen ? ExclusionMode.Ignore : ExclusionMode.Normal
    WlrLayershell.layer: fullscreen ? WlrLayer.Overlay : WlrLayer.Top
    mask: Region {}

    // Same placement as the audio drawer (BarDrawer.anchorEdge / rightInset).
    readonly property real anchorEdge: (anchorItem && anchorItem.parent)
        ? anchorItem.parent.x + anchorItem.x + anchorItem.width
        : barWindow.width - Theme.gap
    readonly property int rightInset: Math.max(0, Math.min(barWindow.width - implicitWidth,
                                               Math.round(barWindow.width - anchorEdge - Theme.gap)))

    // The OSD sits where the notification stack does, so it holds the stack like a popout.
    onShownChanged: Notifs.setHold(osd, shown)
    Component.onDestruction: Notifs.setHold(osd, false)

    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }
    readonly property bool input: Osd.kind === "input"
    readonly property var node: input ? Pipewire.defaultAudioSource : Pipewire.defaultAudioSink
    readonly property var nodeAudio: node ? node.audio : null
    readonly property real level: nodeAudio ? nodeAudio.volume : 0
    readonly property bool muted: nodeAudio ? nodeAudio.muted : false

    DrawerShadow {
        width: osd.contentWidth
        height: card.implicitHeight
        anchors.right: parent.right
        anchors.rightMargin: Theme.gap
        y: card.y
        topLeftRadius:  0
        topRightRadius: 0
    }

    Rectangle {
        id: card
        width: osd.contentWidth
        anchors.right: parent.right
        anchors.rightMargin: Theme.gap
        implicitHeight: col.implicitHeight + 2 * Theme.pad
        topLeftRadius:     0
        topRightRadius:    0
        bottomLeftRadius:  Theme.radius
        bottomRightRadius: Theme.radius
        color: Theme.bar
        y: -height * (1 - osd.reveal)

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: Theme.pad
            spacing: 4                       // the audio drawer's spacing

            SectionHeader {
                Layout.fillWidth: true
                text: osd.input ? "INPUT" : "OUTPUT"
                detail: Math.round(osd.level * 100) + "%"
            }
            SliderRow {
                glyph: osd.input ? (osd.muted ? Theme.iMicOff : Theme.iMic)
                                 : Theme.volGlyph(osd.level, osd.muted)
                glyphColor: osd.muted ? Theme.dim : Theme.text
                sliderEnabled: !!osd.nodeAudio && !osd.muted
                value: osd.level
            }
        }
    }
}
