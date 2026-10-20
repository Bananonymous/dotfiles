pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Pending pacman + AUR updates, checked hourly.
// `qs ipc call updates refresh` re-checks (the update terminal calls it when done).
// runUpgrade() opens scripts/update.sh in kitty: one sudo prompt, then yay -Syu --noconfirm.
Singleton {
    id: root

    property int pacman: 0
    property int aur: 0
    property bool checked: false
    readonly property int total: pacman + aur

    function refresh() {
        if (!proc.running) proc.running = true;
    }

    // True while the update terminal is open
    readonly property bool upgrading: upgradeProc.running

    function runUpgrade() {
        if (!upgradeProc.running) upgradeProc.running = true;
    }

    // The terminal itself, so the bar knows when it's closed
    Process {
        id: upgradeProc
        command: ["kitty", "--class", "qs-update", "--title", "System update",
                  Quickshell.shellPath("scripts/update.sh")]
        onExited: root.refresh()
    }

    Process {
        id: proc
        command: ["bash", "-c", "echo $(checkupdates 2>/dev/null | wc -l) $(yay -Qua 2>/dev/null | wc -l)"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [p, a] = text.trim().split(" ").map(Number);
                root.pacman = p || 0;
                root.aur = a || 0;
                root.checked = true;
            }
        }
    }

    Timer {
        interval: 3600 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    IpcHandler {
        target: "updates"
        function refresh(): void { root.refresh(); }
    }
}
