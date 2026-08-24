import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import "AudioModel.js" as AudioModel

// Audio module: output volume + output device picker, input volume + input device picker.
// Pure Pipewire: default sink/source are bound through the tracker so their `audio` is live;
// the pickable device rows only need registry fields (name/description/nickname/type).
BarDrawer {
    id: audio
    contentWidth: 340
    spacing: 4

    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var sinkAudio: sink ? sink.audio : null
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var sourceAudio: source ? source.audio : null

    // Optimistic levels the sliders display. The live Pipewire value round-trips
    // asynchronously, which made the slider's glide fire only every other click; driving it
    // from a local value set synchronously on input makes the animation deterministic.
    // External changes (media keys) are mirrored back in via the handlers below.
    property real volumeLevel: 0
    property real inputLevel: 0
    Component.onCompleted: {
        if (sinkAudio) volumeLevel = sinkAudio.volume;
        if (sourceAudio) inputLevel = sourceAudio.volume;
    }
    onSinkAudioChanged: if (sinkAudio) volumeLevel = sinkAudio.volume
    onSourceAudioChanged: if (sourceAudio) inputLevel = sourceAudio.volume
    Connections {
        target: audio.sinkAudio
        function onVolumeChanged() { audio.volumeLevel = audio.sinkAudio.volume; }
    }
    Connections {
        target: audio.sourceAudio
        function onVolumeChanged() { audio.inputLevel = audio.sourceAudio.volume; }
    }

    readonly property var nodes: Pipewire.nodes.values
    readonly property var sinks: nodes.filter(function (n) { return n && n.isSink && !n.isStream; })
    readonly property var sources: nodes.filter(function (n) {
        return n && !n.isSink && !n.isStream && n.name !== "quickshell"
            && AudioModel.isAudioSource(n.type, PwNodeType.AudioSource);
    })
    function isDefault(n, d) { return !!(n && d && n.id === d.id); }

    // ── Output ───────────────────────────────────────────────────────
    SectionHeader { Layout.fillWidth: true; text: "OUTPUT"; detail: Math.round(audio.volumeLevel * 100) + "%" }
    SliderRow {
        glyph: Theme.volGlyph(audio.sinkAudio ? audio.sinkAudio.volume : 0,
                              audio.sinkAudio ? audio.sinkAudio.muted : false)
        glyphColor: audio.sinkAudio && audio.sinkAudio.muted ? Theme.dim : Theme.text
        sliderEnabled: !(audio.sinkAudio && audio.sinkAudio.muted)
        value: audio.volumeLevel
        onMoved: (v) => {
            audio.volumeLevel = v;                                   // optimistic, synchronous
            if (audio.sinkAudio) audio.sinkAudio.volume = v;         // apply to Pipewire (async)
        }
        onGlyphClicked: if (audio.sinkAudio) audio.sinkAudio.muted = !audio.sinkAudio.muted
    }
    Repeater {
        model: audio.sinks
        delegate: ListRow {
            required property var modelData
            glyph: Theme.audioGlyph(AudioModel.sinkKind(modelData))
            label: AudioModel.nodeLabel(modelData)
            trailing: audio.isDefault(modelData, audio.sink) ? Theme.iCheck : ""
            onClicked: Pipewire.preferredDefaultAudioSink = modelData
        }
    }

    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.elevated }

    // ── Input ────────────────────────────────────────────────────────
    SectionHeader { Layout.fillWidth: true; text: "INPUT"; detail: Math.round(audio.inputLevel * 100) + "%" }
    SliderRow {
        glyph: audio.sourceAudio && audio.sourceAudio.muted ? Theme.iMicOff : Theme.iMic
        glyphColor: audio.sourceAudio && audio.sourceAudio.muted ? Theme.dim : Theme.text
        sliderEnabled: !!audio.sourceAudio && !audio.sourceAudio.muted
        value: audio.inputLevel
        onMoved: (v) => {
            audio.inputLevel = v;
            if (audio.sourceAudio) audio.sourceAudio.volume = v;
        }
        onGlyphClicked: if (audio.sourceAudio) audio.sourceAudio.muted = !audio.sourceAudio.muted
    }
    Repeater {
        model: audio.sources
        delegate: ListRow {
            required property var modelData
            glyph: Theme.audioGlyph(AudioModel.sourceKind(modelData))
            label: AudioModel.nodeLabel(modelData)
            trailing: audio.isDefault(modelData, audio.source) ? Theme.iCheck : ""
            onClicked: Pipewire.preferredDefaultAudioSource = modelData
        }
    }
}
