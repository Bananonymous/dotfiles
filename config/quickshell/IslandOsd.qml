import QtQuick
import QtQuick.Layouts

// Volume / mic level, shown briefly after a change.
Item {
    id: root

    property string kind: "volume"
    readonly property bool mic: kind === "mic"
    readonly property real level: mic ? Audio.micVolume : Audio.volume
    readonly property bool muted: mic ? Audio.micMuted : Audio.muted

    implicitWidth: 340
    implicitHeight: 46

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        spacing: 12

        Glyph {
            text: root.mic ? (root.muted ? Style.iMicMuted : Style.iMic) : Audio.icon
            size: 19
            color: root.muted ? Colors.outline : Colors.primary
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 8
            radius: 4
            color: Colors.surfaceContainerHighest

            Rectangle {
                width: parent.width * Math.min(1, root.level)
                height: parent.height
                radius: 4
                color: root.muted ? Colors.outline : Colors.primary
                Behavior on width { SpringAnimation { spring: 5; damping: 0.35; epsilon: 0.3 } }
                Behavior on color { ColorAnimation { duration: 200 } }
            }
        }

        Label {
            Layout.preferredWidth: 42
            horizontalAlignment: Text.AlignRight
            text: root.muted ? "muted" : `${Math.round(root.level * 100)}%`
            font.weight: Font.DemiBold
            color: root.muted ? Colors.outline : Colors.surfaceText
        }
    }
}
