import QtQuick

// Icon + label button: hover wash, springy press, scroll, delayed tooltip.
Rectangle {
    id: chip

    property string icon: ""
    property string text: ""
    property color fg: Colors.surfaceText
    property color iconColor: fg
    property color hoverBg: Colors.surfaceContainerHighest
    property string tooltip: ""
    property int iconSize: 15
    property int fontSize: Style.fontSize
    property bool mono: false
    property int padding: 11
    readonly property bool hovered: mouse.containsMouse

    signal clicked(int button)
    signal scrolled(int dir)

    implicitHeight: Style.chipHeight
    implicitWidth: row.implicitWidth + padding * 2
    radius: height / 2
    color: hovered ? hoverBg : "transparent"
    Behavior on color { ColorAnimation { duration: 160 } }

    scale: mouse.pressed ? 0.88 : 1
    Behavior on scale { SpringAnimation { spring: 6; damping: 0.28; epsilon: 0.005 } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: chip.icon && chip.text ? 6 : 0

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: chip.icon !== ""
            text: chip.icon
            color: chip.iconColor
            font.family: Style.iconFont
            font.pixelSize: chip.iconSize
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: chip.text !== ""
            text: chip.text
            color: chip.fg
            font.family: chip.mono ? Style.monoFont : Style.font
            font.pixelSize: chip.fontSize
            font.weight: Font.Medium
            font.features: { "tnum": 1 }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: e => chip.clicked(e.button)
        onWheel: w => chip.scrolled(w.angleDelta.y > 0 ? 1 : -1)
    }

    Timer {
        id: tipDelay
        interval: 450
        running: chip.hovered && chip.tooltip !== ""
    }

    Tip {
        target: chip
        text: chip.tooltip
        show: chip.hovered && !tipDelay.running && !mouse.pressed
    }
}
