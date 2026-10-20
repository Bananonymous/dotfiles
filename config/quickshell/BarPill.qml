import QtQuick
import QtQuick.Layouts

// One floating group in the bar.
Rectangle {
    default property alias content: row.data
    property int padding: 4
    property alias spacing: row.spacing

    implicitHeight: Style.barHeight
    implicitWidth: row.implicitWidth + padding * 2
    radius: Style.pillRadius
    color: Qt.alpha(Colors.surfaceContainerLowest, 0.9)
    border.width: 1
    border.color: Qt.alpha(Colors.outlineVariant, 0.4)

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 2
    }
}
