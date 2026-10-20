import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell

// Battery ring (laptop) or CPU ring (desktop), brightness/volume, session buttons,
// power profiles. The top-left counter is today's screen time; click it for details.
DropPanel {
    id: root

    signal showScreenTime()
    signal close()

    implicitWidth: 320
    implicitHeight: Power.hasBacklight ? 506 : 476
    width: implicitWidth
    height: implicitHeight

    readonly property real ringValue: Power.hasBattery ? Power.level : SysInfo.cpu / 100
    readonly property string ringText: `${Math.round(ringValue * 100)}%`
    readonly property string ringSub: Power.hasBattery
        ? (Power.charging ? "CHARGING" : Power.full ? "FULL" : Power.onBattery ? "ON BATTERY" : "NOT CHARGING")
        : "CPU LOAD"
    readonly property int screenSec: ScreenTime.totalOf(ScreenTime.dayKey(0))

    // Two-step buttons: first click arms (red), second within 3 s runs
    component SessionButton: Rectangle {
        id: sb
        property string icon: ""
        property string label: ""
        property var command: []
        property bool confirm: true
        property bool armed: false
        Layout.fillWidth: true
        implicitHeight: 54
        radius: 12
        color: armed ? Colors.error : (sm.containsMouse ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh)
        Behavior on color { ColorAnimation { duration: 160 } }
        scale: sm.pressed ? 0.93 : 1
        Behavior on scale { SpringAnimation { spring: 6; damping: 0.3; epsilon: 0.005 } }
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 2
            Glyph { Layout.alignment: Qt.AlignHCenter; text: sb.icon; size: 17; color: sb.armed ? Colors.errorText : Colors.surfaceText }
            Label { Layout.alignment: Qt.AlignHCenter; text: sb.armed ? "Sure?" : sb.label; size: 9; color: sb.armed ? Colors.errorText : Colors.surfaceVariantText }
        }
        MouseArea {
            id: sm
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (!sb.confirm || sb.armed) {
                    sb.armed = false;
                    root.close();
                    Quickshell.execDetached(sb.command);
                } else {
                    sb.armed = true;
                    disarm.restart();
                }
            }
        }
        Timer { id: disarm; interval: 3000; onTriggered: sb.armed = false }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 14

        // Screen time today (HR : MIN) + log out
        RowLayout {
            Layout.fillWidth: true
            MouseArea {
                implicitWidth: counter.implicitWidth
                implicitHeight: counter.implicitHeight
                cursorShape: Qt.PointingHandCursor
                onClicked: root.showScreenTime()
                RowLayout {
                    id: counter
                    spacing: 6
                    component Box: Rectangle {
                        property string value: ""
                        property string unit: ""
                        implicitWidth: 38; implicitHeight: 38; radius: 8
                        color: Colors.surfaceContainerHigh
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: -2
                            Label { Layout.alignment: Qt.AlignHCenter; text: parent.parent.value; size: 13; font.weight: Font.Bold }
                            Label { Layout.alignment: Qt.AlignHCenter; text: parent.parent.unit; size: 7; color: Colors.outline }
                        }
                    }
                    Box { value: String(Math.floor(root.screenSec / 3600)).padStart(2, "0"); unit: "HR" }
                    Label { text: ":"; color: Colors.outline }
                    Box { value: String(Math.floor(root.screenSec % 3600 / 60)).padStart(2, "0"); unit: "MIN"; color: Qt.alpha(Colors.primary, 0.18) }
                }
            }
            Item { Layout.fillWidth: true }
            SessionButton {
                Layout.fillWidth: false
                implicitWidth: 38
                implicitHeight: 38
                icon: Style.iLogout
                label: ""
                command: ["uwsm", "stop"]
            }
        }

        // The ring
        Item {
            id: ring
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 190
            implicitHeight: 190

            property real shown: root.ringValue
            Behavior on shown { SpringAnimation { spring: 2.5; damping: 0.35; epsilon: 0.002 } }

            Rectangle {
                anchors.centerIn: parent
                width: 150; height: 150; radius: 75
                color: Qt.alpha(Power.hasBattery && Power.level < 0.2 ? Colors.error : Colors.primary, 0.12)
            }
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Colors.surfaceContainerHighest
                    strokeWidth: 12
                    PathAngleArc { centerX: 95; centerY: 95; radiusX: 82; radiusY: 82; startAngle: 0; sweepAngle: 360 }
                }
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Power.hasBattery && Power.level < 0.15 ? Colors.error : Colors.primary
                    strokeWidth: 12
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: 95; centerY: 95; radiusX: 82; radiusY: 82
                        startAngle: -90
                        sweepAngle: 360 * Math.max(0.002, Math.min(1, ring.shown))
                    }
                }
            }
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 0
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6
                    Glyph {
                        text: Power.hasBattery ? (Power.charging ? Style.iCharging : Style.iBattery) : Style.iCpu
                        size: 20
                        color: Colors.surfaceVariantText
                    }
                    Label { text: root.ringText; size: 34; font.weight: Font.Bold }
                }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.ringSub
                    size: 9
                    color: Colors.surfaceVariantText
                    font.letterSpacing: 1
                }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    visible: Power.hasBattery && Power.eta > 0
                    text: `${Math.floor(Power.eta / 3600)}h ${Math.floor(Power.eta % 3600 / 60)}m ${Power.charging ? "to full" : "left"}`
                    size: 9
                    color: Colors.outline
                }
            }
        }

        // Brightness (laptop) + volume
        component BarSlider: RowLayout {
            property string icon: ""
            property real value: 0
            signal moved(real v)
            Layout.fillWidth: true
            spacing: 12
            Glyph { text: parent.icon; size: 14; color: Colors.primary }
            Item {
                Layout.fillWidth: true
                implicitHeight: 14
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width; height: 8; radius: 4
                    color: Colors.surfaceContainerHighest
                    Rectangle {
                        width: parent.width * Math.min(1, parent.parent.parent.value)
                        height: parent.height; radius: 4
                        color: Colors.primary
                        Behavior on width { NumberAnimation { duration: 150 } }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onPressed: e => parent.parent.moved(e.x / width)
                    onPositionChanged: e => { if (pressed) parent.parent.moved(Math.max(0, Math.min(1, e.x / width))); }
                    onWheel: w => parent.parent.moved(Math.max(0, Math.min(1, parent.parent.value + (w.angleDelta.y > 0 ? 0.03 : -0.03))))
                }
            }
        }
        BarSlider {
            visible: Power.hasBacklight
            icon: Style.iSun
            value: Power.brightness
            onMoved: v => Power.setBrightness(v)
        }
        BarSlider {
            icon: Audio.icon
            value: Audio.volume
            onMoved: v => Audio.setVolume(v)
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            SessionButton { icon: Style.iLock; label: "Lock"; command: ["hyprlock"]; confirm: false }
            SessionButton { icon: Style.iSleep; label: "Sleep"; command: ["systemctl", "suspend"] }
            SessionButton { icon: Style.iReboot; label: "Reboot"; command: ["systemctl", "reboot"] }
            SessionButton { icon: Style.iPower; label: "Power"; command: ["systemctl", "poweroff"] }
        }

        // Power profiles
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 38
            radius: 12
            color: Colors.surfaceContainer

            readonly property var profiles: Power.hasPerformance
                ? [["performance", Style.iGauge, "Perform"], ["balanced", Style.iScale, "Balance"], ["power-saver", Style.iLeaf, "Saver"]]
                : [["balanced", Style.iScale, "Balance"], ["power-saver", Style.iLeaf, "Saver"]]
            readonly property int current: Math.max(0, profiles.findIndex(p => p[0] === Power.profile))

            Rectangle {
                x: 3 + parent.current * (parent.width - 6) / parent.profiles.length
                y: 3
                width: (parent.width - 6) / parent.profiles.length
                height: parent.height - 6
                radius: 10
                color: Colors.primary
                Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            }
            Row {
                anchors.fill: parent
                anchors.margins: 3
                Repeater {
                    model: parent.parent.profiles
                    MouseArea {
                        required property var modelData
                        width: parent.width / parent.parent.profiles.length
                        height: parent.height
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Power.setProfile(modelData[0])
                        Label {
                            anchors.centerIn: parent
                            text: `${parent.modelData[1]} ${parent.modelData[2]}`
                            size: 11
                            color: Power.profile === parent.modelData[0] ? Colors.primaryText : Colors.surfaceVariantText
                        }
                    }
                }
            }
        }
    }
}
