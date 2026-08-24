import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts
import "PowerModel.js" as PowerModel

// Power module: battery hero + charge bar, battery stats, power profile, session actions.
// Percentages go through Theme.dispPct so the BIOS 80% charge cap reads as full.
BarDrawer {
    id: pop
    contentWidth: 360
    spacing: Theme.pad

    readonly property var dev: UPower.displayDevice
    readonly property real raw: dev ? dev.percentage : 0
    readonly property int pct: Theme.dispPct(Math.round(raw > 1 ? raw : raw * 100))
    readonly property int state: dev ? dev.state : UPowerDeviceState.Unknown
    readonly property bool charging: state === UPowerDeviceState.Charging
    readonly property bool pluggedIn: !UPower.onBattery
    readonly property bool low: pct <= 10
    readonly property var states: ({ Charging: UPowerDeviceState.Charging, FullyCharged: UPowerDeviceState.FullyCharged })

    // Cycle count is sysfs-only (UPower does not expose it); read once per open.
    property int cycles: -1
    Process {
        id: cyclesRead
        command: ["cat", "/sys/class/power_supply/" + (pop.dev && pop.dev.nativePath ? pop.dev.nativePath : "BAT1") + "/cycle_count"]
        stdout: StdioCollector {
            onStreamFinished: { var n = parseInt(text); pop.cycles = isNaN(n) ? -1 : n }
        }
    }
    onShownChanged: if (shown) cyclesRead.running = true

    DrawerHero {
        glyph: Theme.batteryGlyph(pop.pct, pop.charging)
        glyphColor: (pop.charging || pop.pluggedIn) ? Theme.accent2 : (pop.low ? Theme.danger : Theme.text)
        title: "Battery  " + pop.pct + "%"
        status: PowerModel.statusLine(pop.state, pop.pluggedIn,
                                      pop.dev ? pop.dev.timeToFull : 0,
                                      pop.dev ? pop.dev.timeToEmpty : 0, pop.states)
    }

    // ── Charge bar ───────────────────────────────────────────────────
    Item {
        Layout.fillWidth: true
        implicitHeight: 8
        Rectangle { id: track; anchors.fill: parent; radius: 4; color: Theme.elevated }
        Rectangle {
            height: parent.height
            radius: 4
            color: (pop.charging || pop.pluggedIn) ? Theme.accent2 : (pop.low ? Theme.danger : Theme.accent)
            width: Math.max(height, track.width * pop.pct / 100)
            Behavior on width { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: Theme.animMed } }
            // Slow pulse while charging: energy is flowing in.
            SequentialAnimation on opacity {
                running: pop.charging && pop.shown
                loops: Animation.Infinite
                alwaysRunToEnd: true
                NumberAnimation { from: 1.0; to: 0.55; duration: 950; easing.type: Easing.InOutSine }
                NumberAnimation { from: 0.55; to: 1.0; duration: 950; easing.type: Easing.InOutSine }
            }
        }
    }

    // ── Stats ────────────────────────────────────────────────────────
    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Theme.pad * 2
        rowSpacing: 4
        InfoPair { label: "Battery size";  value: PowerModel.formatWh(pop.dev ? pop.dev.energyCapacity : 0) }
        InfoPair {
            label: pop.pluggedIn ? "Time to full" : "Time left"
            value: PowerModel.formatDuration(pop.pluggedIn ? (pop.dev ? pop.dev.timeToFull : 0)
                                                            : (pop.dev ? pop.dev.timeToEmpty : 0))
        }
        InfoPair { label: "Charge cycles"; value: pop.cycles >= 0 ? String(pop.cycles) : "--" }
        InfoPair {
            label: pop.pluggedIn ? "Charging" : "Discharging"
            value: PowerModel.formatWatts(pop.dev ? pop.dev.changeRate : 0)
        }
    }

    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.elevated }

    // ── Power profile (power-profiles-daemon via Quickshell) ─────────
    SectionHeader { Layout.fillWidth: true; text: "POWER PROFILE" }
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.gap
        Pill {
            glyph: Theme.iLeaf; label: "Saver"
            active: PowerProfiles.profile === PowerProfile.PowerSaver
            onClicked: PowerProfiles.profile = PowerProfile.PowerSaver
        }
        Pill {
            glyph: Theme.iBalanced; label: "Balanced"
            active: PowerProfiles.profile === PowerProfile.Balanced
            onClicked: PowerProfiles.profile = PowerProfile.Balanced
        }
        Pill {
            visible: PowerProfiles.hasPerformanceProfile
            glyph: Theme.iSpeedometer; label: "Performance"
            active: PowerProfiles.profile === PowerProfile.Performance
            onClicked: PowerProfiles.profile = PowerProfile.Performance
        }
    }

    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.elevated }

    // ── Session row ──────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.gap
        PowerBtn { glyph: Theme.iLock;    cmd: ["loginctl", "lock-session"] }
        PowerBtn { glyph: Theme.iSuspend; cmd: ["systemctl", "suspend"] }
        PowerBtn { glyph: Theme.iReboot;  cmd: ["systemctl", "reboot"] }
        PowerBtn { glyph: Theme.iPower;   cmd: ["systemctl", "poweroff"]; danger: true }
    }

    component InfoPair: RowLayout {
        property string label: ""
        property string value: ""
        Layout.fillWidth: true
        Text {
            text: label
            color: Theme.dim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
        }
        Item { Layout.fillWidth: true }
        Text {
            text: value
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
        }
    }
}
