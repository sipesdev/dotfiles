import QtQuick
import Quickshell.Services.Pipewire

// Audio module pill: graded volume glyph from the default sink.
BarIcon {
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    readonly property var a: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
    glyph: Theme.volGlyph(a ? a.volume : 0, a ? a.muted : false)
    glyphColor: a && a.muted ? Theme.dim : Theme.text
}
