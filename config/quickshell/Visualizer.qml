import QtQuick

// cava bars, each easing toward its target height.
Row {
    id: root

    property int count: Media.bars.length
    property real barWidth: 3
    property color accent: Colors.primary
    property bool mirrored: false   // grow from the middle instead of the bottom

    spacing: 2

    Repeater {
        model: root.count

        Item {
            required property int index
            width: root.barWidth
            height: root.height

            Rectangle {
                readonly property real v: Media.bars[Math.floor(parent.index * Media.bars.length / root.count)] ?? 0
                width: parent.width
                height: Math.max(width, v * parent.height)
                anchors.bottom: root.mirrored ? undefined : parent.bottom
                anchors.verticalCenter: root.mirrored ? parent.verticalCenter : undefined
                radius: width / 2
                color: root.accent
                Behavior on height { NumberAnimation { duration: 90 } }
            }
        }
    }
}
