import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Volume / mic level pill under the bar on the focused screen, shown briefly after a change.
PanelWindow {
    id: root

    property bool on: false
    property string kind: "volume"
    property bool armed: false      // ignore the "changes" PipeWire reports at startup

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    WlrLayershell.namespace: "quickshell-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    anchors.top: true
    margins.top: Style.barHeight + 18
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 360
    implicitHeight: 56
    color: "transparent"
    visible: pill.opacity > 0.01
    mask: Region {}

    Timer { interval: 2500; running: true; onTriggered: root.armed = true }
    Timer { id: hide; interval: 1500; onTriggered: root.on = false }

    Connections {
        target: Audio
        function onOsd(kind) {
            if (!root.armed) return;
            root.kind = kind;
            root.on = true;
            hide.restart();
        }
    }

    Rectangle {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        width: 340
        height: 46
        radius: 23
        color: Qt.alpha(Colors.surfaceContainerLowest, 0.96)
        border.width: 1
        border.color: Qt.alpha(Colors.outlineVariant, 0.5)

        y: root.on ? 0 : -20
        opacity: root.on ? 1 : 0
        scale: root.on ? 1 : 0.85
        Behavior on y { NumberAnimation { duration: 320; easing.type: Easing.OutBack } }
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack } }

        IslandOsd {
            anchors.fill: parent
            kind: root.kind
        }
    }
}
