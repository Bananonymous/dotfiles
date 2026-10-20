import QtQuick
import Quickshell

// Hover tooltip that drops below its target chip.
PopupWindow {
    id: tip

    required property Item target
    property string text: ""
    property bool show: false

    anchor.item: target
    anchor.rect.x: (target.width - implicitWidth) / 2
    anchor.rect.y: target.height + 10
    visible: show && text !== ""
    implicitWidth: label.implicitWidth + 20
    implicitHeight: label.implicitHeight + 14
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: Colors.surfaceContainerHigh
        border.width: 1
        border.color: Colors.outlineVariant

        Text {
            id: label
            anchors.centerIn: parent
            text: tip.text
            color: Colors.surfaceText
            font.family: Style.font
            font.pixelSize: Style.fontSize - 1
        }
    }
}
