import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

// StatusNotifier tray: left click activates, right click opens the app's menu.
RowLayout {
    id: root

    spacing: 4
    visible: SystemTray.items.values.length > 0
    Layout.leftMargin: 6
    Layout.rightMargin: 6

    Repeater {
        model: SystemTray.items

        MouseArea {
            id: slot

            required property SystemTrayItem modelData

            // Some apps send "name?path=/dir" instead of a themeable icon name
            readonly property string iconSource: {
                const icon = modelData.icon;
                if (!icon.includes("?path=")) return icon;
                const [name, path] = icon.split("?path=");
                return `file://${path}/${name.slice(name.lastIndexOf("/") + 1)}`;
            }

            implicitWidth: 24
            implicitHeight: Style.chipHeight
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor

            onClicked: e => {
                if (e.button === Qt.MiddleButton) modelData.secondaryActivate();
                else if (e.button === Qt.RightButton || modelData.onlyMenu) menu.visible ? menu.close() : menu.open();
                else modelData.activate();
            }
            onWheel: w => modelData.scroll(w.angleDelta.y, false)

            Rectangle {
                anchors.centerIn: parent
                width: 24
                height: 24
                radius: 6
                color: slot.containsMouse ? Colors.surfaceContainerHighest : "transparent"
            }

            // Apps with a themed glyph instead of their own icon
            readonly property var glyphIcon: {
                const key = `${modelData.id} ${modelData.icon}`.toLowerCase();
                if (key.includes("firewall")) {
                    const bad = /error|panic|off|disabled/.test(key);
                    return { text: Style.glyph(bad ? 0xf099d : 0xf0565), color: bad ? Colors.error : Colors.primary };
                }
                return null;
            }

            IconImage {
                anchors.centerIn: parent
                implicitSize: 16
                source: slot.iconSource
                visible: !slot.glyphIcon
            }

            Glyph {
                anchors.centerIn: parent
                visible: !!slot.glyphIcon
                text: slot.glyphIcon?.text ?? ""
                color: slot.glyphIcon?.color ?? Colors.surfaceText
                size: 16
                scale: slot.containsMouse ? 1.15 : 1
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
            }

            TrayMenu {
                id: menu
                target: slot
                rootMenu: slot.modelData.menu
            }

            Tip {
                target: slot
                text: slot.modelData.tooltipTitle || slot.modelData.title
                show: slot.containsMouse && !menu.visible
            }
        }
    }
}
