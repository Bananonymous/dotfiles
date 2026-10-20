import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

// Network / Bluetooth "orbit": the connection in a big glowing circle, its details in
// bubbles tied to it by wavy lines. "Switch view" flips to a list to connect something else.
DropPanel {
    id: root

    property string tab: "wifi"         // "wifi" | "bluetooth"
    property bool listView: false
    signal tabSwitched(string tab)

    implicitWidth: 600
    implicitHeight: 466
    width: implicitWidth
    height: implicitHeight

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property BluetoothDevice bt: adapter?.devices.values.find(d => d.connected) ?? null
    readonly property bool connected: tab === "wifi" ? Net.kind !== "none" : bt !== null
    property string btProfile: ""

    onOpenChanged: {
        Net.detailed = open;
        listView = false;
        if (open) { Net.refresh(); profileProc.running = true; }
    }
    onTabChanged: { listView = false; profileProc.running = true; }

    // Bluetooth audio profile of the connected device, from its PipeWire card
    Process {
        id: profileProc
        command: ["pactl", "-f", "json", "list", "cards"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.btProfile = "";
                if (!root.bt) return;
                try {
                    const mac = root.bt.address.replace(/:/g, "_");
                    const card = JSON.parse(text).find(c => c.name.includes(mac));
                    root.btProfile = card ? card.active_profile : "";
                } catch (e) {}
            }
        }
    }

    // What the center and the bubbles say
    readonly property var center: tab === "wifi"
        ? (Net.kind === "wifi" ? { icon: Style.iWifi, title: Net.name, sub: "Connected" }
           : Net.kind === "ethernet" ? { icon: Style.iEthernet, title: Net.name || "Wired", sub: "Connected" }
           : { icon: Style.iWifiOff, title: Net.wifiEnabled ? "Not connected" : "Wi-Fi off", sub: "Switch view to pick one" })
        : (bt ? { icon: Style.iHeadphones, title: bt.name, sub: "Connected" }
           : { icon: Style.iBluetoothOff, title: adapter?.enabled ? "No device" : "Bluetooth off", sub: "Scan to pair one" })

    readonly property var bubbles: !connected ? []
        : tab === "bluetooth" ? [
            { icon: Style.iDevice, value: bt.address, label: "MAC Address", ax: 0.12, ay: 0.42 },
            { icon: Style.iBattery, value: bt.batteryAvailable ? `${Math.round(bt.battery * 100)}%` : "n/a", label: "Battery", ax: 0.9, ay: 0.44 },
            { icon: Style.iHeadphones, value: btProfile ? btProfile.replace(/-/g, " ") : "None", label: "Audio Profile", ax: 0.5, ay: 0.8 }
        ]
        : Net.kind === "wifi" ? [
            { icon: Style.iRadar, value: Net.freq, label: "Band", ax: 0.18, ay: 0.3 },
            { icon: Style.iIp, value: Net.ip || "—", label: "IP Address", ax: 0.16, ay: 0.64 },
            { icon: Style.iSignal, value: `${Net.signal}%`, label: "Signal Strength", ax: 0.88, ay: 0.5 },
            { icon: Style.iShield, value: Net.security || "Open", label: "Security", ax: 0.55, ay: 0.82 }
        ]
        : [
            { icon: Style.iEthernet, value: Net.device, label: "Interface", ax: 0.16, ay: 0.32 },
            { icon: Style.iIp, value: Net.ip || "—", label: "IP Address", ax: 0.16, ay: 0.64 },
            { icon: Style.iGauge, value: Net.linkSpeed ? `${Net.linkSpeed} Mb/s` : "—", label: "Link Speed", ax: 0.88, ay: 0.5 },
            { icon: Style.iDown, value: SysInfo.rate(SysInfo.rxRate).trim(), label: "Download", ax: 0.55, ay: 0.82 }
        ]

    Item {
        id: stage
        anchors.fill: parent
        anchors.bottomMargin: 70
        visible: !root.listView
        opacity: root.listView ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 200 } }

        readonly property real cx: width / 2
        readonly property real cy: height / 2 + 6
        readonly property real r: 66

        // Slow wobble shared by the tether lines and the bubbles
        property real t: 0
        NumberAnimation on t { from: 0; to: Math.PI * 2; duration: 6000; loops: Animation.Infinite; running: root.open }

        // Halo rings
        Repeater {
            model: [2.2, 1.55, 1.18]
            Rectangle {
                required property real modelData
                required property int index
                x: stage.cx - width / 2
                y: stage.cy - height / 2
                width: stage.r * 2 * modelData
                height: width
                radius: width / 2
                color: Qt.alpha(Colors.primary, root.connected ? [0.03, 0.06, 0.16][index] : 0.03)
                scale: root.open ? 1 : 0.6
                Behavior on scale { NumberAnimation { duration: 500 + index * 120; easing.type: Easing.OutBack } }
            }
        }

        // Tethers + bubbles
        Repeater {
            model: root.bubbles

            Item {
                id: sat
                required property var modelData
                required property int index
                anchors.fill: parent

                readonly property real bx: stage.width * modelData.ax
                readonly property real by: stage.height * modelData.ay + Math.sin(stage.t + index * 1.6) * 4
                readonly property real ang: Math.atan2(by - stage.cy, bx - stage.cx)
                readonly property real sx: stage.cx + Math.cos(ang) * (stage.r + 4)
                readonly property real sy: stage.cy + Math.sin(ang) * (stage.r + 4)

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: Qt.alpha(Colors.surfaceText, 0.35)
                        strokeWidth: 1.2
                        startX: sat.sx; startY: sat.sy
                        PathCubic {
                            x: sat.bx; y: sat.by
                            control1X: (sat.sx * 2 + sat.bx) / 3 + Math.sin(stage.t * 2 + sat.index) * 10
                            control1Y: (sat.sy * 2 + sat.by) / 3 - 12
                            control2X: (sat.sx + sat.bx * 2) / 3
                            control2Y: (sat.sy + sat.by * 2) / 3 + Math.cos(stage.t * 2 + sat.index) * 10
                        }
                    }
                }

                Rectangle {
                    x: sat.bx - width / 2
                    y: sat.by - height / 2
                    width: Math.max(120, info.implicitWidth + 22)
                    height: 42
                    radius: 10
                    color: Qt.alpha(Colors.surfaceContainerHigh, 0.9)
                    border.width: 1
                    border.color: Qt.alpha(Colors.outlineVariant, 0.6)
                    scale: root.progress > 0.95 ? 1 : 0.3
                    opacity: scale
                    Behavior on scale { NumberAnimation { duration: 380 + sat.index * 90; easing.type: Easing.OutBack } }

                    RowLayout {
                        id: info
                        anchors.centerIn: parent
                        spacing: 8
                        Glyph { text: sat.modelData.icon; size: 14; color: Colors.primary }
                        ColumnLayout {
                            spacing: -1
                            Label { text: sat.modelData.value; size: 11; font.weight: Font.Bold; Layout.maximumWidth: 130 }
                            Label { text: sat.modelData.label; size: 8; color: Colors.surfaceVariantText }
                        }
                    }
                }
            }
        }

        // Switch view / scan bubble at the top
        Rectangle {
            x: stage.cx - width / 2
            y: 34
            width: sw.implicitWidth + 26
            height: 40
            radius: 10
            color: swm.containsMouse ? Colors.surfaceContainerHighest : "transparent"
            border.width: 1
            border.color: Colors.outline
            RowLayout {
                id: sw
                anchors.centerIn: parent
                spacing: 8
                Glyph { text: Style.iSearch; size: 13 }
                ColumnLayout {
                    spacing: -1
                    Label { text: root.tab === "wifi" ? "Networks" : "Scan Devices"; size: 11; font.weight: Font.Bold }
                    Label { text: "Switch View"; size: 8; color: Colors.surfaceVariantText }
                }
            }
            MouseArea {
                id: swm
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.listView = true;
                    if (root.tab === "wifi") Net.scan();
                    else if (root.adapter) root.adapter.discovering = true;
                }
            }
        }
        Shape {
            anchors.fill: parent
            ShapePath {
                fillColor: "transparent"
                strokeColor: Qt.alpha(Colors.surfaceText, 0.35)
                strokeWidth: 1.2
                startX: stage.cx; startY: 74
                PathQuad { x: stage.cx; y: stage.cy - stage.r - 4; controlX: stage.cx + Math.sin(stage.t) * 12; controlY: (74 + stage.cy - stage.r) / 2 }
            }
        }

        // The core
        Rectangle {
            id: core
            x: stage.cx - width / 2
            y: stage.cy - height / 2
            width: stage.r * 2
            height: width
            radius: width / 2
            color: root.connected ? Colors.primary : Colors.surfaceContainerHighest
            Behavior on color { ColorAnimation { duration: 300 } }
            scale: root.open ? (coreMouse.pressed ? 0.94 : 1) : 0.5
            Behavior on scale { SpringAnimation { spring: 4; damping: 0.28; epsilon: 0.005 } }

            // Breathing pulse while connected
            SequentialAnimation on border.width {
                running: root.connected && root.open
                loops: Animation.Infinite
                NumberAnimation { from: 0; to: 6; duration: 1400; easing.type: Easing.InOutSine }
                NumberAnimation { from: 6; to: 0; duration: 1400; easing.type: Easing.InOutSine }
            }
            border.color: Qt.alpha(Colors.primary, 0.35)

            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width - 20
                spacing: 1
                Glyph {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.center.icon
                    size: 26
                    color: root.connected ? Colors.primaryText : Colors.surfaceVariantText
                }
                Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.center.title
                    size: 12
                    font.weight: Font.Bold
                    color: root.connected ? Colors.primaryText : Colors.surfaceText
                }
                Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.center.sub
                    size: 9
                    color: root.connected ? Qt.alpha(Colors.primaryText, 0.75) : Colors.outline
                    wrapMode: Text.Wrap
                }
            }
            MouseArea {
                id: coreMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.listView = true
            }
        }
    }

    // ── List view: networks or devices ──
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 22
        anchors.bottomMargin: 76
        visible: root.listView
        opacity: root.listView ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Chip { icon: Style.iChevronLeft; padding: 6; onClicked: root.listView = false }
            Label {
                Layout.fillWidth: true
                text: root.tab === "wifi" ? "Wi-Fi networks" : "Bluetooth devices"
                size: 14
                font.weight: Font.Bold
            }
            Chip {
                icon: Style.iReboot
                text: root.tab === "wifi" ? "Rescan" : (root.adapter?.discovering ? "Scanning…" : "Scan")
                fontSize: 11
                onClicked: root.tab === "wifi" ? Net.scan() : (root.adapter.discovering = !root.adapter.discovering)
            }
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 6
            model: root.tab === "wifi" ? Net.networks
                : [...(root.adapter?.devices.values ?? [])].sort((a, b) => b.connected - a.connected || b.paired - a.paired)

            delegate: Rectangle {
                id: row
                required property var modelData
                readonly property bool isWifi: root.tab === "wifi"
                readonly property bool active: isWifi ? modelData.active : modelData.connected
                width: ListView.view.width
                height: 46
                radius: 12
                color: active ? Qt.alpha(Colors.primary, 0.18) : (rm.containsMouse ? Colors.surfaceContainerHigh : Colors.surfaceContainer)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 10
                    spacing: 12
                    Glyph {
                        text: row.isWifi ? Style.iWifi : (row.modelData.icon?.includes("audio") ? Style.iHeadphones : Style.iBluetooth)
                        color: row.active ? Colors.primary : Colors.surfaceVariantText
                        size: 16
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: -1
                        Label {
                            Layout.fillWidth: true
                            text: row.isWifi ? row.modelData.ssid : (row.modelData.name || row.modelData.address)
                            font.weight: Font.DemiBold
                        }
                        Label {
                            Layout.fillWidth: true
                            text: row.isWifi ? `${row.modelData.signal}%  ·  ${row.modelData.secure ? row.modelData.security : "open"}`
                                : row.modelData.connected ? "Connected" : row.modelData.paired ? "Paired" : "Available"
                            size: 10
                            color: Colors.surfaceVariantText
                        }
                    }
                    Label {
                        text: row.active ? "Disconnect" : "Connect"
                        size: 10
                        color: row.active ? Colors.error : Colors.primary
                    }
                }
                MouseArea {
                    id: rm
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (row.isWifi) {
                            if (row.active) Quickshell.execDetached(["nmcli", "con", "down", "id", row.modelData.ssid]);
                            else Net.connect(row.modelData.ssid, row.modelData.secure, false);
                        } else if (row.active) row.modelData.disconnect();
                        else if (row.modelData.paired) row.modelData.connect();
                        else row.modelData.pair();
                    }
                }
            }
        }
    }

    // ── Bottom: tabs + radio power ──
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 22
        width: 240
        height: 32
        radius: 10
        color: Colors.surfaceContainer

        Rectangle {
            x: root.tab === "wifi" ? 3 : parent.width / 2
            y: 3
            width: parent.width / 2 - 3
            height: parent.height - 6
            radius: 8
            color: Colors.primary
            Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        }
        Row {
            anchors.fill: parent
            Repeater {
                model: [["wifi", Style.iWifi, "Wi-Fi"], ["bluetooth", Style.iBluetooth, "Bluetooth"]]
                MouseArea {
                    required property var modelData
                    width: parent.width / 2
                    height: parent.height
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.tabSwitched(modelData[0])
                    Label {
                        anchors.centerIn: parent
                        text: `${parent.modelData[1]}  ${parent.modelData[2]}`
                        size: 11
                        color: root.tab === parent.modelData[0] ? Colors.primaryText : Colors.surfaceVariantText
                    }
                }
            }
        }
    }

    Chip {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 20
        readonly property bool on: root.tab === "wifi" ? Net.wifiEnabled : (root.adapter?.enabled ?? false)
        icon: Style.iPower
        iconSize: 15
        padding: 9
        implicitHeight: 36
        color: on ? Colors.primary : Colors.surfaceContainerHigh
        hoverBg: color
        iconColor: on ? Colors.primaryText : Colors.surfaceVariantText
        tooltip: root.tab === "wifi" ? "Wi-Fi radio" : "Bluetooth"
        onClicked: root.tab === "wifi" ? Net.setWifi(!on) : (root.adapter.enabled = !on)
    }
}
