import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Layouts

// Notification center: history, do-not-disturb, clear all.
DropPanel {
    id: root

    implicitWidth: 420
    implicitHeight: Math.min(560, 120 + Math.max(1, Notifs.count) * 110)
    width: implicitWidth
    height: implicitHeight
    Behavior on implicitHeight { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Label { text: "Notifications"; size: 15; font.weight: Font.Bold }
            Rectangle {
                visible: Notifs.count > 0
                implicitWidth: n.implicitWidth + 12; implicitHeight: 20; radius: 10
                color: Colors.primary
                Label { id: n; anchors.centerIn: parent; text: Notifs.count; size: 10; font.weight: Font.Bold; color: Colors.primaryText }
            }
            Item { Layout.fillWidth: true }
            Chip {
                icon: Notifs.dnd ? Style.iBellOff : Style.iBell
                text: Notifs.dnd ? "DND on" : "DND off"
                fontSize: 10
                iconSize: 12
                color: Notifs.dnd ? Colors.primary : (hovered ? hoverBg : "transparent")
                fg: Notifs.dnd ? Colors.primaryText : Colors.surfaceVariantText
                onClicked: Notifs.dnd = !Notifs.dnd
            }
            Chip {
                visible: Notifs.count > 0
                icon: Style.iTrash
                text: "Clear"
                fontSize: 10
                iconSize: 12
                fg: Colors.surfaceVariantText
                onClicked: Notifs.clearAll()
            }
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: Notifs.count > 0
            clip: true
            spacing: 8
            model: [...Notifs.history].reverse()
            QQC.ScrollBar.vertical: QQC.ScrollBar { policy: QQC.ScrollBar.AsNeeded }
            delegate: NotifCard {
                required property var modelData
                width: ListView.view.width
                notif: modelData
                compact: true
                color: Colors.surfaceContainer
            }
            add: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 250 }
                NumberAnimation { property: "x"; from: -30; to: 0; duration: 350; easing.type: Easing.OutBack }
            }
            displaced: Transition { NumberAnimation { properties: "y"; duration: 250; easing.type: Easing.OutCubic } }
        }

        Item {
            visible: Notifs.count === 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            Column {
                anchors.centerIn: parent
                spacing: 6
                Glyph { anchors.horizontalCenter: parent.horizontalCenter; text: Style.iBell; size: 30; color: Colors.outlineVariant }
                Label { anchors.horizontalCenter: parent.horizontalCenter; text: "All caught up"; color: Colors.outline }
            }
        }
    }
}
