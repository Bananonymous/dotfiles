pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Open-Meteo forecast for wherever the public IP says we are (scripts/weather.py).
Singleton {
    id: root

    property var data: null
    readonly property bool ready: data !== null
    readonly property var days: data?.days ?? []

    function refresh() { if (!proc.running) proc.running = true; }

    Process {
        id: proc
        command: ["python3", "-I", Quickshell.shellPath("scripts/weather.py")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    if (!d.error) root.data = d;
                } catch (e) {}
            }
        }
    }

    Timer {
        // Retry quickly until the first success, then every 20 minutes
        interval: root.ready ? 20 * 60 * 1000 : 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
