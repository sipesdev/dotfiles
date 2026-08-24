import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts

// Battery popout on the shared drawer shell. Task 10 grows this into the Power module.
BarDrawer {
    id: pop
    contentWidth: 240
    spacing: 4

    readonly property var dev: UPower.displayDevice
    readonly property real raw: dev ? dev.percentage : 0
    readonly property int pct: Theme.dispPct(Math.round(raw > 1 ? raw : raw * 100))
    readonly property bool charging: dev ? dev.state === UPowerDeviceState.Charging : false
    readonly property bool pluggedIn: !UPower.onBattery

    function fmt(sec) {
        if (!sec || sec <= 0) return "—";
        var h = Math.floor(sec / 3600);
        var m = Math.floor((sec % 3600) / 60);
        return (h > 0 ? h + "h " : "") + m + "m";
    }

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
