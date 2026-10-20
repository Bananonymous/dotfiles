import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Notification toasts, top-right of the focused screen. Each slides in, shows a countdown
// line (paused while hovered), then slides out. Up to 3 at a time.
PanelWindow {
    id: root

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    WlrLayershell.namespace: "quickshell-toasts"
    WlrLayershell.layer: WlrLayer.Overlay
    anchors {
        top: true
        right: true
    }
    margins {
        top: Style.barHeight + 14
        right: 12
    }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 400
    implicitHeight: Math.max(1, column.implicitHeight)
    visible: Notifs.queue.length > 0 || column.children.length > 1
    color: "transparent"
    mask: Region { item: column }

    Column {
        id: column
        width: parent.width
        spacing: 10

        Repeater {
            model: Notifs.queue.slice(0, 3)

            Item {
                id: toast
                required property var modelData
                readonly property int lifetime: Notifs.toastMs(modelData)
                property real remaining: 1
                width: column.width
                height: card.implicitHeight

                HoverHandler { id: hover }

                NotifCard {
                    id: card
                    width: parent.width
                    notif: toast.modelData
                    color: Qt.alpha(Colors.surfaceContainerLowest, 0.97)
                    border.width: 1
                    border.color: Qt.alpha(Colors.primary, 0.45)

                    // Slide in from the right
                    x: 420
                    Component.onCompleted: x = 0
                    Behavior on x { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 0.8 } }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.margins: 1
                        anchors.leftMargin: 18
                        width: (parent.width - 36) * toast.remaining
                        height: 2
                        radius: 1
                        color: Colors.primary
                        visible: toast.lifetime > 0
                    }
                }

                NumberAnimation on remaining {
                    from: 1; to: 0
                    duration: Math.max(1, toast.lifetime)
                    running: toast.lifetime > 0
                    paused: running && hover.hovered
                    onFinished: Notifs.dropToast(toast.modelData)
                }
            }
        }
    }
}
