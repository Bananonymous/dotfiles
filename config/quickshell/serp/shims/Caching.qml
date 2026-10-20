pragma Singleton
import QtQuick
import Quickshell

// Where the ported files live (their scripts and assets resolve from here).
Singleton {
    readonly property string qsDir: Quickshell.shellPath("serp")
    readonly property string serpantinumDir: Quickshell.shellPath("serp")
    readonly property string runDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/serpantinum"
}
