import QtQuick
import QtQuick.Layouts

// Quick-settings tile: rounded square when off, morphs to a filled pill when on.
Rectangle {
    id: root

    property bool on: false
    property string icon: ""
    property string label: ""
    property string sublabel: ""

    signal toggled()

    implicitHeight: 52
    implicitWidth: 150
    radius: on ? height / 2 : 14
    color: on ? Colors.primary : (mouse.containsMouse ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh)
    Behavior on radius { SpringAnimation { spring: 4; damping: 0.3; epsilon: 0.2 } }
    Behavior on color { ColorAnimation { duration: 220 } }

    scale: mouse.pressed ? 0.94 : 1
    Behavior on scale { SpringAnimation { spring: 6; damping: 0.3; epsilon: 0.005 } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 12
        spacing: 10

        Glyph {
            text: root.icon
            size: 19
            color: root.on ? Colors.primaryText : Colors.surfaceText
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Label {
                Layout.fillWidth: true
                text: root.label
                font.weight: Font.DemiBold
                color: root.on ? Colors.primaryText : Colors.surfaceText
            }
            Label {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.sublabel
                size: 11
                color: root.on ? Colors.primaryText : Colors.surfaceVariantText
                opacity: 0.85
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
