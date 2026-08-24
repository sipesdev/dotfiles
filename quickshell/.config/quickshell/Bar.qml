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

    // ── Popout arbitration: exactly one drawer open, keyed by name ───
    // Drawers bind `shown` to this and ask closePopout() from their focus grab; the pills
    // call togglePopout(). Switching A -> B never passes through "" so the notification
    // hold below is never dropped mid-switch.
    property string openPopout: ""
    function togglePopout(key) { openPopout = (openPopout === key) ? "" : key; }
    function closePopout(key)  { if (openPopout === key) openPopout = ""; }
    readonly property bool popoutOpen: openPopout !== ""

    // ── LEFT: Arch launcher + workspaces ─────────────────────────────
    Row {
        id: left
        anchors.left: parent.left
        anchors.leftMargin: Theme.gap
        height: parent.height
        spacing: Theme.pad

        ArchButton  { anchors.verticalCenter: parent.verticalCenter }
        Workspaces  { anchors.verticalCenter: parent.verticalCenter }
    }

    // ── CENTER: clock (true center, independent of side widths) ──────
    Clock {
        anchors.centerIn: parent
    }

    // ── RIGHT: tray + status/power + battery ─────────────────────────
    Row {
        id: right
        anchors.right: parent.right
        anchors.rightMargin: Theme.gap
        height: parent.height
        spacing: 0   // pills carry their own padding; matches the left gap

        SysTray { anchors.verticalCenter: parent.verticalCenter }
        BarIcon {
            id: btIcon
            anchors.verticalCenter: parent.verticalCenter
            glyph: Theme.btGlyph(Sys.btOn, Sys.btConnected)
            glyphColor: Sys.btConnected ? Theme.accent : (Sys.btOn ? Theme.text : Theme.dim)
            active: bar.openPopout === "bluetooth"
            onClicked: bar.togglePopout("bluetooth")
        }
        BarIcon {
            id: netIcon
            anchors.verticalCenter: parent.verticalCenter
            // Wired takes over the network slot when docked (Wi-Fi is auto-off then).
            glyph: Sys.ethernetConnected ? Theme.iEthernet
                 : Theme.wifiGlyph(Sys.wifiEnabled, Sys.wifiConnected, Sys.wifiStrength)
            glyphColor: (Sys.ethernetConnected || Sys.wifiEnabled) ? Theme.text : Theme.dim
            active: bar.openPopout === "network"
            onClicked: bar.togglePopout("network")
        }
        StatusButton {
            id: statusBtn
            anchors.verticalCenter: parent.verticalCenter
            active: bar.openPopout === "status"
            onToggled: bar.togglePopout("status")
        }
        Battery {
            id: batteryIcon
            anchors.verticalCenter: parent.verticalCenter
            active: bar.openPopout === "power"
            onClicked: bar.togglePopout("power")
        }
    }

    // Popouts (one drawer per module; each lines up under its pill)
    StatusPowerCenter { barWindow: bar; key: "status"; anchorItem: statusBtn }
    PowerDrawer       { barWindow: bar; key: "power";  anchorItem: batteryIcon }
    BluetoothDrawer   { barWindow: bar; key: "bluetooth"; anchorItem: btIcon }
    NetworkDrawer     { barWindow: bar; key: "network";   anchorItem: netIcon }

    // Notifications share the popouts' top-right corner, so an open popout holds the
    // stack: arrivals queue and visible cards freeze until it closes. Cleared on
    // destruction too, or unplugging this monitor would strand the hold forever.
    NotificationLayer { barScreen: bar.screen }

    onPopoutOpenChanged: Notifs.setHold(bar, popoutOpen)
    Component.onDestruction: Notifs.setHold(bar, false)
}
