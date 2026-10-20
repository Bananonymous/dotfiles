import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell.Widgets

// A panel that drops out of its bar pill: grows from a small faded box under the pill
// (with a little overshoot), then its contents fade in. Closing runs it backwards, faster.
Item {
    id: panel

    property bool open: false
    property real pivotX: width / 2     // where the pill is, in panel coordinates
    default property alias content: body.data
    property real progress: 0
    readonly property bool shown: progress > 0.001

    visible: shown
    enabled: open

    onOpenChanged: {
        anim.stop();
        anim.from = progress;
        anim.to = open ? 1 : 0;
        anim.duration = open ? 420 : 200;
        anim.easing.type = open ? Easing.OutBack : Easing.InCubic;
        anim.start();
    }
    NumberAnimation {
        id: anim
        target: panel
        property: "progress"
        easing.overshoot: 0.9
    }

    transform: Scale {
        origin.x: panel.pivotX
        origin.y: 0
        xScale: 0.55 + 0.45 * panel.progress
        yScale: 0.25 + 0.75 * panel.progress
    }
    opacity: Math.min(1, panel.progress * 2.2)

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Style.panelRadius
        color: Qt.alpha(Colors.surfaceContainerLowest, 0.96)
        border.width: 1
        border.color: Qt.alpha(Colors.outlineVariant, 0.5)

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.alpha(Colors.shadow, 0.6)
            shadowBlur: 1
            shadowVerticalOffset: 6
            blurMax: 40
        }
    }

    // Faint concentric rings behind the content, like the reference. Clipped to the
    // panel's rounded shape: inside bg's shadow layer they spilled out past its edges.
    ClippingRectangle {
        anchors.fill: parent
        radius: Style.panelRadius
        color: "transparent"

        Repeater {
            model: 3
            Rectangle {
                required property int index
                readonly property real size: Math.max(parent.width, parent.height) * (0.55 + index * 0.32)
                x: parent.width * 0.62 - size / 2
                y: parent.height * 0.45 - size / 2
                width: size
                height: size
                radius: size / 2
                color: "transparent"
                border.width: 40 + index * 30
                border.color: Qt.alpha(Colors.primary, 0.025)
            }
        }
    }

    Item {
        id: body
        anchors.fill: parent
        opacity: Math.max(0, (panel.progress - 0.45) / 0.55)
    }
}
