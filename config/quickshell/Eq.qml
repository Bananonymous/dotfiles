pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// 10-band equalizer driving the PipeWire filter-chain in
// ~/.config/pipewire/filter-chain.conf.d/qs-eq.conf (node "effect_input.qs_eq").
// Gains are saved to the shell's state dir and re-applied whenever the node appears.
Singleton {
    id: root

    readonly property var freqs: [31, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    readonly property var labels: ["31", "63", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"]
    readonly property real maxDb: 12

    readonly property var presets: ({
        "Flat":    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        "Bass":    [7, 6, 4.5, 2.5, 0.5, 0, 0, 0, 0, 0],
        "Treble":  [0, 0, 0, 0, 0, 0.5, 2, 4, 5.5, 6.5],
        "Vocal":   [-2, -2, -1, 1.5, 3.5, 4, 3, 1.5, 0, -1],
        "Pop":     [-1, 1, 3, 4, 3, 0, -1, -1, 1, 2],
        "Rock":    [5, 4, 2, -1, -2, -1, 1.5, 3, 4, 4.5],
        "Jazz":    [3, 2, 1, 2, -1.5, -1.5, 0, 1.5, 3, 3.5],
        "Classic": [4.5, 3.5, 2.5, 1, -1, -1, 0, 2, 3, 4]
    })
    readonly property var presetNames: ["Flat", "Bass", "Treble", "Vocal", "Pop", "Rock", "Jazz", "Classic"]

    property var gains: presets.Flat
    property string preset: "Flat"     // "Custom" once a band is dragged
    property bool saved: true

    readonly property PwNode node: Pipewire.nodes.values.find(n => n.name === "effect_input.qs_eq") ?? null
    readonly property bool available: node !== null
    onNodeChanged: if (node) applyAll()

    function applyAll() {
        if (!node) return;
        const params = gains.map((g, i) => `"eq_band_${i + 1}:Gain" ${g.toFixed(2)}`).join(" ");
        Quickshell.execDetached(["pw-cli", "s", String(node.id), "Props", `{ params = [ ${params} ] }`]);
    }

    function setBand(i, db) {
        const g = gains.slice();
        g[i] = Math.max(-maxDb, Math.min(maxDb, Math.round(db * 2) / 2));
        gains = g;
        preset = "Custom";
        pending.restart();
    }

    // Exact gains under a name (used by the ported media popup's own presets)
    function setAll(values, name) {
        gains = values.map(v => Math.max(-maxDb, Math.min(maxDb, Number(v) || 0)));
        preset = name;
        pending.restart();
    }

    function usePreset(name) {
        gains = presets[name].slice();
        preset = name;
        pending.restart();
    }

    // Coalesce slider drags into one pw-cli call + one save
    Timer {
        id: pending
        interval: 60
        onTriggered: {
            root.applyAll();
            root.saved = false;
            saveLater.restart();
        }
    }
    Timer {
        id: saveLater
        interval: 800
        onTriggered: {
            store.setText(JSON.stringify({ gains: root.gains, preset: root.preset }));
            root.saved = true;
        }
    }

    FileView {
        id: store
        path: Quickshell.statePath("eq.json")
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                if (d.gains?.length === 10) root.gains = d.gains;
                root.preset = d.preset ?? "Custom";
                root.applyAll();
            } catch (e) {}
        }
    }
}
