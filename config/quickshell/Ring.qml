import QtQuick
import QtQuick.Shapes

// Circular gauge with the value sweeping in on a spring.
Item {
    id: root

    property real value: 0      // 0..1
    property string icon: ""
    property string text: ""
    property color accent: Colors.primary
    property real thickness: 5
    property real shown: value
    Behavior on shown { SpringAnimation { spring: 3; damping: 0.35; epsilon: 0.002 } }

    implicitWidth: 64
    implicitHeight: 64

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: Colors.surfaceContainerHighest
            strokeWidth: root.thickness
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2; centerY: root.height / 2
                radiusX: root.width / 2 - root.thickness; radiusY: radiusX
                startAngle: 135; sweepAngle: 270
            }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.accent
            strokeWidth: root.thickness
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2; centerY: root.height / 2
                radiusX: root.width / 2 - root.thickness; radiusY: radiusX
                startAngle: 135; sweepAngle: 270 * Math.max(0.001, Math.min(1, root.shown))
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: -1
        Glyph {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.icon
            size: 15
            color: root.accent
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.text
            size: 11
            font.weight: Font.DemiBold
        }
    }
}
