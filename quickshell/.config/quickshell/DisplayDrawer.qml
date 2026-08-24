import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// Display module: backlight slider + auto-brightness toggle. All writes go through the backlight
// wrapper, which owns the panel's safe ceiling: 100 here is the brightest the panel actually reaches.
BarDrawer {
    id: disp
    contentWidth: 300
    spacing: 4

    readonly property string home: Quickshell.env("HOME")

    property int brightness: 50
    Process {
        id: brightRead
        command: [disp.home + "/.local/bin/backlight", "get"]
        stdout: StdioCollector {
            onStreamFinished: { var n = parseInt(text); if (!isNaN(n)) disp.brightness = n }
        }
    }
    Process { id: brightSet }
    function setBrightness(pct) {
        disp.brightness = pct;
        brightSet.command = [disp.home + "/.local/bin/backlight", "set", String(pct)];
        brightSet.running = true;
    }
    // Re-read brightness whenever auto-brightness toggles, so the slider snaps to
    // the real value the moment it's turned on or off...
    Connections {
        target: Sys
        function onAutoBrightnessChanged() { brightRead.running = true }
    }
    // ...and keep the slider synced while the drawer is open, so hardware
    // brightness-key presses (and auto-brightness) are reflected live. The backlight
    // exposes no reliable change signal for file-watching, so poll. Paused while the
    // user is dragging the slider, so a stale read-back can't fight the input.
    Timer {
        interval: 300; repeat: true
        running: disp.shown && !slider.pressed
        onTriggered: brightRead.running = true
    }
    onShownChanged: if (shown) brightRead.running = true

    SectionHeader { Layout.fillWidth: true; text: "BRIGHTNESS"; detail: disp.brightness + "%" }
    SliderRow {
        id: slider
        glyph: Theme.iSun
        glyphColor: Sys.autoBrightness ? Theme.accent : Theme.text
        fill: Theme.accent2
        sliderEnabled: !Sys.autoBrightness
        value: disp.brightness / 100
        onMoved: (v) => disp.setBrightness(Math.max(1, Math.round(v * 100)))
        onGlyphClicked: Sys.autoBrightness = !Sys.autoBrightness
    }
    ToggleRow {
        Layout.fillWidth: true
        glyph: Theme.iBrightnessAuto
        label: "Auto-brightness"
        on: Sys.autoBrightness
        onToggled: Sys.autoBrightness = !Sys.autoBrightness
    }
}
