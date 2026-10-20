import QtQuick

// Boxed icon button: lightens and grows a little on hover, grows on press, pops on click.
// Modeled on ilyamiro's Serpantinum IconButton (AGPL-3.0).
Item {
    id: root

    property int size: 30
    property int cornerRadius: 10
    property string icon: ""
    property int iconSize: 12
    property color accentColor: Colors.surfaceContainerHigh
    property color textColor: Colors.surfaceVariantText
    property color hoverTextColor: Colors.surfaceText
    readonly property bool hovered: ma.containsMouse

    signal clicked()

    implicitWidth: size
    implicitHeight: size

    property real popScale: 1.0

    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: ma.pressed ? Qt.darker(root.accentColor, 1.12)
             : root.hovered ? Qt.lighter(root.accentColor, 1.12)
             : root.accentColor
        Behavior on color { ColorAnimation { duration: 180 } }

        scale: (ma.pressed ? 1.08 : root.hovered ? 1.04 : 1.0) * root.popScale
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

        Glyph {
            anchors.centerIn: parent
            text: root.icon
            size: root.iconSize
            color: root.hovered ? root.hoverTextColor : root.textColor
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        // White flash on click
        Rectangle {
            id: flash
            anchors.fill: parent
            radius: root.cornerRadius
            color: "#ffffff"
            opacity: 0
            NumberAnimation on opacity { id: flashAnim; running: false; from: 0.25; to: 0; duration: 400; easing.type: Easing.OutExpo }
        }
    }

    SequentialAnimation {
        id: pop
        NumberAnimation { target: root; property: "popScale"; to: 1.1; duration: 110; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "popScale"; to: 1.0; duration: 420; easing.type: Easing.OutQuint }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            pop.restart();
            flashAnim.restart();
            root.clicked();
        }
    }
}
