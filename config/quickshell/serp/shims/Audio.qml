pragma Singleton
import QtQuick
import Quickshell
import "../.." as Root

Singleton {
    readonly property bool hasActiveStream: Root.Media.playing
}
