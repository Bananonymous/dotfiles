import QtQuick

// Thick Material 3 style slider: filled track, gap, thin handle. Drag, click or scroll.
Item {
    id: root

    property real value: 0          // 0..1
    property string icon: ""
    property bool dim: false        // e.g. muted
    property color accent: Colors.primary
    readonly property real shown: drag.active ? dragValue : value
    property real dragValue: 0

    signal moved(real v)
    signal iconClicked()

    implicitHeight: 40
    implicitWidth: 240

    function at(x) { return Math.max(0, Math.min(1, (x - track.x) / track.width)); }

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: Colors.surfaceContainerHighest
        clip: true

        Rectangle {
            id: fill
            height: parent.height
            width: Math.max(height, root.shown * parent.width)
            radius: height / 2
            color: root.dim ? Colors.outline : root.accent
            Behavior on width { enabled: !drag.active; SpringAnimation { spring: 5; damping: 0.4; epsilon: 0.3 } }
            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }

    Glyph {
        anchors.left: parent.left
        anchors.leftMargin: 13
        anchors.verticalCenter: parent.verticalCenter
        text: root.icon
        size: 18
        color: root.dim ? Colors.surfaceText : Colors.primaryText

        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: root.iconClicked()
        }
    }

    Label {
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: `${Math.round(root.shown * 100)}%`
        color: root.shown > 0.85 && !root.dim ? Colors.primaryText : Colors.surfaceVariantText
        font.weight: Font.DemiBold
    }

    MouseArea {
        anchors.fill: parent
        anchors.leftMargin: 40
        cursorShape: Qt.PointingHandCursor
        onPressed: e => root.moved(root.at(e.x + anchors.leftMargin))
        onWheel: w => root.moved(Math.max(0, Math.min(1, root.value + (w.angleDelta.y > 0 ? 0.03 : -0.03))))
    }

    DragHandler {
        id: drag
        target: null
        xAxis.enabled: true
        yAxis.enabled: false
        onCentroidChanged: if (active) {
            root.dragValue = root.at(centroid.position.x);
            root.moved(root.dragValue);
        }
    }
}
