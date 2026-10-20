import QtQuick
import Quickshell
import Quickshell.Hyprland

// Workspaces 1-8 as square buttons. The active highlight is one block whose leading
// edge moves fast and trailing edge slow, so it stretches as it slides.
Item {
    id: root

    required property HyprlandMonitor monitor
    readonly property int count: 8
    readonly property int slot: 28
    readonly property int spacing: 3
    readonly property var ids: {
        const set = new Set([...Array(count).keys()].map(i => i + 1));
        for (const ws of Hyprland.workspaces.values)
            if (ws.id > 0 && ws.monitor === monitor) set.add(ws.id);
        return [...set].sort((a, b) => a - b);
    }
    readonly property int activeIndex: Math.max(0, ids.indexOf(monitor?.activeWorkspace?.id ?? -1))

    // This Hyprland config is Lua: `dispatch` takes an hl.dsp expression
    function goTo(target) {
        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${JSON.stringify(target)} })`);
    }

    implicitWidth: ids.length * slot + (ids.length - 1) * spacing
    implicitHeight: slot

    property real targetLeft: activeIndex * (slot + spacing)
    property bool movingRight: true
    // Direction first, then the edges, so each edge's Behavior picks the right speed
    onTargetLeftChanged: {
        movingRight = targetLeft > blob.from;
        blob.from = targetLeft;
        blob.to = targetLeft + slot;
    }
    Item {
        id: blob
        property real from: 0
        property real to: root.slot
        Behavior on from { NumberAnimation { duration: root.movingRight ? 380 : 180; easing.type: Easing.OutCubic } }
        Behavior on to { NumberAnimation { duration: root.movingRight ? 180 : 380; easing.type: Easing.OutCubic } }
    }
    Rectangle {
        x: blob.from
        width: blob.to - blob.from
        height: root.height
        radius: Style.chipRadius
        color: Colors.primary
    }

    Repeater {
        model: root.ids

        Item {
            id: cell

            required property int modelData
            required property int index
            readonly property HyprlandWorkspace ws: Hyprland.workspaces.values.find(w => w.id === modelData) ?? null
            readonly property bool active: index === root.activeIndex
            readonly property bool occupied: (ws?.toplevels.values.length ?? 0) > 0
            readonly property bool urgent: ws?.urgent ?? false

            x: index * (root.slot + root.spacing)
            width: root.slot
            height: root.height

            Rectangle {
                anchors.fill: parent
                radius: Style.chipRadius
                color: cell.urgent ? Colors.error : Colors.surfaceContainerHigh
                opacity: cell.active ? 0 : cell.urgent ? 1 : mouse.containsMouse ? 1 : 0.55
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }

            Label {
                anchors.centerIn: parent
                text: cell.modelData
                size: 12
                font.weight: cell.active ? Font.Bold : Font.Medium
                color: cell.active ? Colors.primaryText
                     : cell.urgent ? Colors.errorText
                     : cell.occupied ? Colors.surfaceText
                     : Colors.outline
                Behavior on color { ColorAnimation { duration: 200 } }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.goTo(cell.modelData)
            }
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: e => root.goTo(e.angleDelta.y > 0 ? "e-1" : "e+1")
    }
}
