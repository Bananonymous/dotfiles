import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications

// One notification: icon/image, app + age, summary, body, action buttons, close.
Rectangle {
    id: root

    required property Notification notif
    property bool compact: false     // history list: tighter, 2-line body
    readonly property bool critical: notif?.urgency === NotificationUrgency.Critical
    readonly property string iconSource: {
        if (!notif) return "";
        if (notif.image) return notif.image;
        const name = notif.appIcon || notif.desktopEntry;
        if (!name) return "";
        return name.startsWith("/") || name.includes("://") ? name : Quickshell.iconPath(name, true);
    }

    implicitHeight: body.implicitHeight + 24
    radius: 18
    color: critical ? Qt.alpha(Colors.error, 0.16)
         : hover.hovered ? Colors.surfaceContainerHigh : Colors.surfaceContainer
    border.width: critical ? 1 : 0
    border.color: Colors.error
    Behavior on color { ColorAnimation { duration: 160 } }

    HoverHandler { id: hover }

    RowLayout {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 12

        // App icon or image; a bell if the app sent neither
        Rectangle {
            Layout.alignment: Qt.AlignTop
            implicitWidth: root.compact ? 36 : 44
            implicitHeight: implicitWidth
            radius: 12
            color: Colors.secondaryContainer
            clip: true

            IconImage {
                anchors.fill: parent
                anchors.margins: root.notif?.image ? 0 : 6
                source: root.iconSource
                visible: root.iconSource !== ""
            }
            Glyph {
                anchors.centerIn: parent
                visible: root.iconSource === ""
                text: Style.iBell
                color: Colors.secondaryContainerText
                size: 18
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Label {
                    text: root.notif?.appName || "Notification"
                    size: 11
                    color: Colors.primary
                    font.weight: Font.DemiBold
                }
                Label {
                    Layout.fillWidth: true
                    text: Notifs.ago(root.notif) ? "· " + Notifs.ago(root.notif) : ""
                    size: 11
                    color: Colors.outline
                }
                Chip {
                    icon: Style.iClose
                    iconSize: 13
                    padding: 5
                    implicitHeight: 22
                    fg: Colors.surfaceVariantText
                    onClicked: root.notif.dismiss()
                }
            }
            Label {
                Layout.fillWidth: true
                text: root.notif?.summary ?? ""
                size: 14
                font.weight: Font.DemiBold
                maximumLineCount: 1
            }
            Label {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.notif?.body ?? ""
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                maximumLineCount: root.compact ? 2 : 4
                color: Colors.surfaceVariantText
            }
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 6
                visible: actionRepeater.count > 0

                Repeater {
                    id: actionRepeater
                    model: (root.notif?.actions ?? []).filter(a => a.identifier !== "default")
                    Chip {
                        required property var modelData
                        text: modelData.text
                        color: Colors.secondaryContainer
                        hoverBg: Colors.secondary
                        fg: hovered ? Colors.secondaryText : Colors.secondaryContainerText
                        onClicked: { modelData.invoke(); root.notif.dismiss(); }
                    }
                }
            }
        }
    }

    // Click the body: run the default action
    TapHandler {
        onTapped: Notifs.activate(root.notif)
    }
}
