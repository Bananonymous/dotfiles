import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

// Screen time: day picker, averages, week bars, month heatmap, top apps.
DropPanel {
    id: root

    property int offset: 0      // 0 = today, -1 = yesterday, ...
    readonly property string day: ScreenTime.dayKey(offset)
    readonly property int total: ScreenTime.totalOf(day)
    readonly property int prev: ScreenTime.totalOf(ScreenTime.dayKey(offset - 1))
    readonly property var week: ScreenTime.week(day)
    readonly property var weekDone: week.filter(d => d.day <= ScreenTime.dayKey(0) && d.seconds > 0)
    readonly property int average: weekDone.length ? weekDone.reduce((a, d) => a + d.seconds, 0) / weekDone.length : 0
    readonly property var apps: ScreenTime.apps(day)

    implicitWidth: 600
    implicitHeight: 486
    width: implicitWidth
    height: implicitHeight

    onOpenChanged: if (open) offset = 0

    component Card: Rectangle {
        radius: 14
        color: Qt.alpha(Colors.surfaceContainer, 0.7)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Chip { icon: Style.iChevronLeft; padding: 7; onClicked: root.offset-- }
            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.offset === 0 ? "Today" : root.offset === -1 ? "Yesterday"
                    : Qt.locale().toString(new Date(root.day + "T12:00:00"), "dddd d MMMM")
                size: 15
                font.weight: Font.Bold
                font.capitalization: Font.Capitalize
            }
            Chip { icon: Style.iChevronRight; padding: 7; enabled: root.offset < 0; opacity: enabled ? 1 : 0.3; onClicked: root.offset++ }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Card {
                Layout.preferredWidth: 150
                implicitHeight: 62
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0
                    Label { Layout.alignment: Qt.AlignHCenter; text: "Daily average"; size: 10; color: Colors.surfaceVariantText }
                    Label { Layout.alignment: Qt.AlignHCenter; text: ScreenTime.fmt(root.average); size: 15; font.weight: Font.Bold }
                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: `${Qt.locale().toString(new Date(root.week[0].day + "T12:00"), "d MMM")} - ${Qt.locale().toString(new Date(root.week[6].day + "T12:00"), "d MMM")}`
                        size: 8
                        color: Colors.outline
                    }
                }
            }
            Card {
                Layout.fillWidth: true
                implicitHeight: 62
                color: Colors.surfaceContainerHigh
                Label {
                    anchors.centerIn: parent
                    text: ScreenTime.fmt(root.total)
                    size: 28
                    font.weight: Font.Bold
                }
            }
            Card {
                Layout.preferredWidth: 150
                implicitHeight: 62
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0
                    readonly property int diff: root.total - root.prev
                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: `${parent.diff >= 0 ? "↑" : "↓"} ${ScreenTime.fmt(Math.abs(parent.diff))}`
                        size: 14
                        font.weight: Font.Bold
                        color: parent.diff >= 0 ? Colors.surfaceText : Colors.primary
                    }
                    Label { Layout.alignment: Qt.AlignHCenter; text: root.offset === 0 ? "vs yesterday" : "vs day before"; size: 9; color: Colors.surfaceVariantText }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // Week bars
            Card {
                id: weekCard
                Layout.fillWidth: true
                implicitHeight: 112
                readonly property int peak: Math.max(3600, ...root.week.map(d => d.seconds))

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8
                    Repeater {
                        model: root.week
                        ColumnLayout {
                            required property var modelData
                            readonly property bool sel: modelData.day === root.day
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 4
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: Math.min(28, parent.width)
                                    height: Math.max(2, parent.height * parent.parent.modelData.seconds / weekCard.peak) * (root.open ? 1 : 0)
                                    radius: 4
                                    color: parent.parent.sel ? Colors.primary : Colors.surfaceContainerHighest
                                    Behavior on height { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                                }
                            }
                            Label {
                                Layout.alignment: Qt.AlignHCenter
                                text: Qt.locale().toString(new Date(parent.modelData.day + "T12:00"), "ddd")
                                size: 9
                                color: parent.sel ? Colors.surfaceText : Colors.outline
                                font.capitalization: Font.Capitalize
                            }
                        }
                    }
                }
            }

            // Month heatmap
            Card {
                Layout.preferredWidth: 220
                implicitHeight: 112
                readonly property date d: new Date(root.day + "T12:00")
                readonly property var cells: {
                    const first = new Date(d.getFullYear(), d.getMonth(), 1);
                    const lead = (first.getDay() + 6) % 7;
                    const n = new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate();
                    const out = [];
                    for (let i = 0; i < lead; i++) out.push(null);
                    for (let i = 1; i <= n; i++) {
                        const k = ScreenTime.key(new Date(d.getFullYear(), d.getMonth(), i));
                        out.push({ key: k, sec: ScreenTime.totalOf(k) });
                    }
                    return out;
                }
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4
                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: Qt.locale().standaloneMonthName(parent.parent.d.getMonth())
                        size: 10
                        font.weight: Font.Bold
                        font.capitalization: Font.Capitalize
                    }
                    Grid {
                        Layout.alignment: Qt.AlignHCenter
                        columns: 7
                        spacing: 3
                        Repeater {
                            model: parent.parent.parent.cells
                            Rectangle {
                                required property var modelData
                                width: 11; height: 11; radius: 3
                                color: !modelData ? "transparent"
                                    : modelData.sec === 0 ? Colors.surfaceContainerHighest
                                    : Qt.alpha(Colors.primary, 0.25 + 0.75 * Math.min(1, modelData.sec / (6 * 3600)))
                                border.width: modelData && modelData.key === root.day ? 1 : 0
                                border.color: Colors.surfaceText
                            }
                        }
                    }
                }
            }
        }

        // Apps
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 6
            model: root.apps.slice(0, 12)
            readonly property int peak: root.apps.length ? root.apps[0].seconds : 1

            delegate: Item {
                required property var modelData
                required property int index
                width: ListView.view.width
                height: 34

                RowLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    spacing: 10
                    IconImage {
                        implicitSize: 16
                        source: ScreenTime.appIcon(parent.parent.modelData.app)
                    }
                    Label { Layout.fillWidth: true; text: ScreenTime.appName(parent.parent.modelData.app); size: 11 }
                    Label { text: ScreenTime.fmt(parent.parent.modelData.seconds); size: 11; color: Colors.surfaceVariantText }
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 4
                    height: 4
                    radius: 2
                    width: (parent.width * 0.55) * parent.modelData.seconds / parent.ListView.view.peak * (root.progress > 0.95 ? 1 : 0)
                    color: Colors.primary
                    Behavior on width { NumberAnimation { duration: 500 + parent.index * 60; easing.type: Easing.OutCubic } }
                }
            }

            Label {
                anchors.centerIn: parent
                visible: root.apps.length === 0
                text: root.offset === 0 ? "Tracking started — check back in a bit" : "No data for this day"
                color: Colors.outline
            }
        }
    }
}
