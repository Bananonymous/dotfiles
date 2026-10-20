pragma Singleton
import QtQuick
import Quickshell

// UI sound effects: off.
Singleton {
    function playSfx(name, volume) {}
    function stopSfx(name) {}
    function playUntilStopped(name) {}
}
