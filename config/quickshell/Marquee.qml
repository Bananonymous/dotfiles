import QtQuick

// Text that scrolls sideways (with a gap, looping) when it doesn't fit its width.
// Behavior modeled on ilyamiro's Serpantinum MarqueeText (AGPL-3.0).
Item {
    id: root

    property alias text: a.text
    property alias font: a.font
    property alias color: a.color
    property bool active: true
    property real gap: 40
    property real speed: 30         // px per second

    readonly property bool overflowing: a.implicitWidth > width
    implicitHeight: a.implicitHeight
    clip: true

    Row {
        id: strip
        spacing: root.gap
        Text { id: a }
        Text {
            visible: root.overflowing
            text: a.text
            font: a.font
            color: a.color
        }

        NumberAnimation on x {
            running: root.active && root.overflowing
            from: 0
            to: -(a.implicitWidth + root.gap)
            duration: (a.implicitWidth + root.gap) / root.speed * 1000
            loops: Animation.Infinite
            onRunningChanged: if (!running) strip.x = 0
        }
    }
}
