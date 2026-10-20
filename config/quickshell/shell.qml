//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io

// Pill bar with drop-down panels on every screen, plus notification toasts and the
// volume OSD on the focused one. Colored live from the wallpaper by matugen.
ShellRoot {
    Variants {
        model: Quickshell.screens
        Bar {}
    }

    Toasts {}
    Osd {}

    // qs ipc call panel toggle clock|media|orbit|power|screentime|notifs
    IpcHandler {
        target: "panel"
        function toggle(name: string): void { Style.panelRequested(name); }
        function eq(preset: string): void { Style.eqPresetRequested(preset); }
    }

    // Start the services that must run even before any panel opens
    Component.onCompleted: [Notifs.dnd, ScreenTime.tick, Eq.available]
}
