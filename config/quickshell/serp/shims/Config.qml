pragma Singleton
import QtQuick
import Quickshell

// No settings file: every lookup falls back to the ported code's defaults.
Singleton {
    property var rawSettings: ({})
    signal settingsLoaded()
    function getSetting(section, fallback) { return fallback; }
}
