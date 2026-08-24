import QtQuick
import Quickshell.Services.Pipewire

// Audio module pill: graded volume glyph from the default sink. Wheel on the pill nudges the
// sink 5% per notch (touchpad fractions accumulate to whole notches); scrolling up from muted
// unmutes first, so a muted pill never looks like it ignores the wheel.
BarIcon {
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    readonly property var a: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
    glyph: Theme.volGlyph(a ? a.volume : 0, a ? a.muted : false)
    glyphColor: a && a.muted ? Theme.dim : Theme.text

    property real wheelAccum: 0
    onScrolled: (delta) => {
        if (!a) return;
        wheelAccum += delta / 120;
        var notches = Math.trunc(wheelAccum);
        if (notches === 0) return;
        wheelAccum -= notches;
        if (notches > 0 && a.muted) a.muted = false;
        a.volume = Math.max(0, Math.min(1, a.volume + notches * 0.05));
    }
}
