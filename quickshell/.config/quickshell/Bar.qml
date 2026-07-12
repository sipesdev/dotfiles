import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: bar

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.barHeight
    color: Theme.bar

    // ── LEFT: Arch launcher + workspaces ─────────────────────────────
    Row {
        id: left
        anchors.left: parent.left
        anchors.leftMargin: Theme.gap
        height: parent.height
        spacing: Theme.pad

        ArchButton { anchors.verticalCenter: parent.verticalCenter }
        Workspaces { anchors.verticalCenter: parent.verticalCenter }
    }

    // ── CENTER: clock (true center, independent of side widths) ──────
    Clock {
        anchors.centerIn: parent
    }

    // ── RIGHT: tray + status/power + battery (added next stage) ──────
    Row {
        id: right
        anchors.right: parent.right
        anchors.rightMargin: Theme.gap
        height: parent.height
        spacing: 0   // status/battery already carry internal padding; matches the left gap

        SysTray { anchors.verticalCenter: parent.verticalCenter }
        StatusButton {
            anchors.verticalCenter: parent.verticalCenter
            onToggled: { batPop.shown = false; powerCenter.shown = !powerCenter.shown }
        }
        Battery {
            anchors.verticalCenter: parent.verticalCenter
            onClicked: { powerCenter.shown = false; batPop.shown = !batPop.shown }
        }
    }

    // Popouts
    StatusPowerCenter { id: powerCenter }
    BatteryPopup { id: batPop }

    // Notifications share the popouts' top-right corner, so an open popout holds the
    // stack: arrivals queue and visible cards freeze until it closes. Cleared on
    // destruction too, or unplugging this monitor would strand the hold forever.
    NotificationLayer { barScreen: bar.screen }

    readonly property bool popoutOpen: powerCenter.shown || batPop.shown
    onPopoutOpenChanged: Notifs.setHold(bar, popoutOpen)
    Component.onDestruction: Notifs.setHold(bar, false)
}
