pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// The MPRIS player worth showing, plus live cava bars while it plays.
Singleton {
    id: root

    // Prefer whatever is playing; otherwise stick with the last one that was
    property MprisPlayer sticky: null
    readonly property MprisPlayer player: {
        const all = Mpris.players.values;
        return all.find(p => p.isPlaying) ?? (all.includes(sticky) ? sticky : null) ?? all[0] ?? null;
    }
    // Deferred so it doesn't feed back into the `player` binding in the same pass
    onPlayerChanged: Qt.callLater(() => { if (player) sticky = player; })

    readonly property bool active: player !== null && (player.trackTitle ?? "") !== ""
    readonly property bool playing: active && (player?.isPlaying ?? false)
    readonly property string title: player?.trackTitle ?? ""
    readonly property string artist: player?.trackArtist ?? ""
    readonly property string art: player?.trackArtUrl ?? ""
    readonly property real length: player?.length ?? 0
    property real position: 0

    // 0..1 per bar, from cava
    property var bars: new Array(24).fill(0)

    function fmt(sec) {
        if (!isFinite(sec) || sec < 0) sec = 0;
        const m = Math.floor(sec / 60), s = Math.floor(sec % 60);
        return `${m}:${s < 10 ? "0" : ""}${s}`;
    }

    // MPRIS doesn't push position updates; poll while visible-worthy
    Timer {
        interval: 500
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: root.position = root.player?.position ?? 0
    }

    Process {
        id: cava
        running: root.playing
        command: ["cava", "-p", Quickshell.shellPath("cava.conf")]
        stdout: SplitParser {
            onRead: line => {
                const v = line.split(";");
                v.pop();
                if (v.length) root.bars = v.map(n => Number(n) / 100);
            }
        }
        onRunningChanged: if (!running) root.bars = new Array(24).fill(0)
    }
}
