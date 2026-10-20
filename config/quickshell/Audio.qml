pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Default PipeWire sink + source, with an `osd` signal whenever either changes.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? true
    readonly property real micVolume: source?.audio?.volume ?? 0
    readonly property bool micMuted: source?.audio?.muted ?? true
    readonly property bool headset: /arctis|headset|headphone/i.test(sink?.description ?? "")
    readonly property string icon: Style.volumeIcon(volume, muted, headset)

    // "volume" or "mic"
    signal osd(string kind)

    function setVolume(v) { if (sink?.audio) sink.audio.volume = Math.max(0, Math.min(1.5, v)); }
    function setMicVolume(v) { if (source?.audio) source.audio.volume = Math.max(0, Math.min(1.5, v)); }
    function toggleMute() { if (sink?.audio) sink.audio.muted = !sink.audio.muted; }
    function toggleMic() { if (source?.audio) source.audio.muted = !source.audio.muted; }

    // Binds the nodes so their audio properties are live
    PwObjectTracker { objects: [root.sink, root.source] }

    Connections {
        target: root.sink?.audio ?? null
        function onVolumeChanged() { root.osd("volume"); }
        function onMutedChanged() { root.osd("volume"); }
    }
    Connections {
        target: root.source?.audio ?? null
        function onVolumeChanged() { root.osd("mic"); }
        function onMutedChanged() { root.osd("mic"); }
    }
}
