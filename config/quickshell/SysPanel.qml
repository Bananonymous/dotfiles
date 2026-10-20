import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io

// CPU, GPU and memory rings, temperatures, CPU history, network rates and the apps
// using the most memory.
// Opened from the RAM island next to the tray. On open, everything arrives in a staggered
// sequence (header, rings sweeping up, cards rising, graphs drawing in, memory bars
// growing); while open, a shimmer runs along each ring and their glowing tips breathe
// faster with the load.
DropPanel {
    id: root

    implicitWidth: 400
    implicitHeight: body.implicitHeight + 36
    width: implicitWidth
    height: implicitHeight

    // [{ name, mib }] summed per command name, so a browser's many processes count once
    property var topMem: []

    Process {
        id: psProc
        command: ["ps", "-eo", "rss=,comm=", "--sort=-rss"]
        stdout: StdioCollector {
            onStreamFinished: {
                const sum = {};
                for (const line of text.split("\n")) {
                    const m = line.trim().match(/^(\d+)\s+(.+)$/);
                    if (m) sum[m[2]] = (sum[m[2]] ?? 0) + Number(m[1]);
                }
                root.topMem = Object.entries(sum)
                    .sort((a, b) => b[1] - a[1])
                    .slice(0, 5)
                    .map(([name, kib]) => ({ name, mib: kib / 1024 }));
            }
        }
    }
    // Only poll processes while the panel is open
    Timer {
        interval: 3000
        running: root.open
        repeat: true
        triggeredOnStart: true
        onTriggered: psProc.running = true
    }

    // Temperatures and GPU from scripts/hwstats.sh, polled only while open
    property var temps: []      // [{ name, c }] main sensors, CPU first
    property var gpu: null      // { name, util, memUsed, memTotal, temp } or null
    readonly property real hottest: Math.max(0, ...temps.map(t => t.c))

    function tempColor(c) {
        return c >= 85 ? Colors.error : c >= 70 ? Colors.orange : c >= 55 ? Colors.yellow : Colors.green;
    }

    Process {
        id: hwProc
        command: [Quickshell.shellPath("scripts/hwstats.sh")]
        stdout: StdioCollector {
            onStreamFinished: {
                const names = { coretemp: "CPU", k10temp: "CPU", zenpower: "CPU", nvme: "NVMe",
                                amdgpu: "GPU", acpitz: "ACPI" };
                const rank = ["CPU", "GPU", "NVMe", "Chipset", "Wi-Fi"];
                const main = {};
                let gpu = null;
                for (const line of text.split("\n")) {
                    const f = line.split("|");
                    if (f[0] === "gpu") {
                        gpu = { name: f[1], util: Number(f[2]), memUsed: Number(f[3]), memTotal: Number(f[4]), temp: Number(f[5]) };
                    } else if (f[0] === "temp") {
                        const [, chip, label] = f, c = Math.round(Number(f[3]) / 1000);
                        if (!(c > 0 && c < 150)) continue;
                        if (/^Core \d+/.test(label)) continue;     // per-core: the package reading covers it
                        const name = names[chip] ?? (chip.startsWith("pch") ? "Chipset" : chip.startsWith("iwlwifi") ? "Wi-Fi" : chip);
                        // One tile per device: keep its hottest reading
                        main[name] = Math.max(main[name] ?? 0, c);
                    }
                }
                if (gpu && gpu.temp > 0) main.GPU = gpu.temp;
                const order = n => { const i = rank.indexOf(n); return i < 0 ? 99 : i; };
                root.temps = Object.entries(main)
                    .sort((a, b) => order(a[0]) - order(b[0]))
                    .slice(0, 6)
                    .map(([name, c]) => ({ name, c }));
                root.gpu = gpu;
            }
        }
    }
    Timer {
        interval: 2000
        running: root.open
        repeat: true
        triggeredOnStart: true
        onTriggered: hwProc.running = true
    }

    // Apps using the most CPU right now: [{ name, share }], share of the whole CPU (0..1).
    // From the change in each process's CPU ticks against the system's total ticks
    // between two reads of /proc (ps only gives lifetime averages).
    property bool cpuTop: false
    property var topCpu: []
    property var lastCpuSample: null
    onCpuTopChanged: { lastCpuSample = null; topCpu = []; }

    Process {
        id: cpuProc
        command: ["sh", "-c", "head -1 /proc/stat; cat /proc/[0-9]*/stat 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                const total = lines[0].trim().split(/\s+/).slice(1).reduce((a, b) => a + Number(b), 0);
                const ticks = {};   // pid -> [comm, utime + stime]
                for (const line of lines.slice(1)) {
                    // "pid (comm) state ..." — comm may itself contain spaces or parens
                    const m = line.match(/^(\d+) \((.*)\) (.*)$/);
                    if (!m) continue;
                    const f = m[3].split(" ");
                    ticks[m[1]] = [m[2], Number(f[11]) + Number(f[12])];
                }
                const last = root.lastCpuSample;
                root.lastCpuSample = { total, ticks };
                if (!last || total <= last.total) return;
                const sum = {};
                for (const pid in ticks) {
                    const before = last.ticks[pid];
                    if (!before) continue;
                    const d = ticks[pid][1] - before[1];
                    if (d > 0) sum[ticks[pid][0]] = (sum[ticks[pid][0]] ?? 0) + d;
                }
                const dt = total - last.total;
                root.topCpu = Object.entries(sum)
                    .sort((a, b) => b[1] - a[1])
                    .slice(0, 5)
                    .map(([name, d]) => ({ name, share: d / dt }));
            }
        }
    }
    Timer {
        interval: 1500
        running: root.open && root.cpuTop
        repeat: true
        triggeredOnStart: true
        onTriggered: cpuProc.running = true
    }
    // Rows of the CPU list slide in each time it's shown
    property real cpuIn: 0
    NumberAnimation { id: cpuInAnim; target: root; property: "cpuIn"; from: 0; to: 1; duration: 700 }

    // ── Entrance choreography ──────────────────────────────────────────────────
    // `intro` runs 0 → 1 once per opening; stage(i) is element i's own eased 0 → 1,
    // starting a little after element i-1's.
    property real intro: 1
    SequentialAnimation {
        id: introAnim
        PropertyAction { target: root; property: "intro"; value: 0 }
        PauseAnimation { duration: 140 }    // let the panel's drop-out land first
        NumberAnimation { target: root; property: "intro"; to: 1; duration: 1800 }
    }
    Connections {
        target: root
        function onOpenChanged() { if (root.open) introAnim.restart(); }
    }

    function clamp01(x) { return Math.max(0, Math.min(1, x)); }
    function easeOut(x) { return 1 - Math.pow(1 - x, 3); }
    function backOut(x) { const c = 1.7; return 1 + (c + 1) * Math.pow(x - 1, 3) + c * Math.pow(x - 1, 2); }
    // Steps are sized so the last element (memory row 5, i ≈ 10.4) still finishes by intro = 1
    readonly property real step: 0.055
    function stage(i, span) { return easeOut(clamp01((intro - i * step) / (span ?? 0.4))); }
    function stageBack(i, span) { return backOut(clamp01((intro - i * step) / (span ?? 0.4))); }

    function gib(v) { return v.toFixed(1); }
    function mib(v) { return v >= 1024 ? `${(v / 1024).toFixed(1)} GiB` : `${Math.round(v)} MiB`; }

    // A card that rises and fades in at its turn
    component Card: Rectangle {
        id: card
        property int order: 0
        readonly property real st: root.stage(card.order)
        default property alias content: inner.data
        Layout.fillWidth: true
        implicitHeight: inner.implicitHeight + 24
        radius: 14
        color: Colors.surfaceContainer
        opacity: st
        transform: Translate { y: (1 - card.st) * 22 }

        property bool clickable: false
        signal clicked()
        // Under the content (declared first), which takes no clicks itself
        MouseArea {
            id: cardMouse
            anchors.fill: parent
            enabled: card.clickable
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: card.clicked()
        }
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Colors.surfaceText
            opacity: cardMouse.containsMouse ? 0.04 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }
        }

        ColumnLayout {
            id: inner
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8
        }
    }

    component CardTitle: RowLayout {
        id: ct
        property string icon: ""
        property string title: ""
        property string value: ""
        Layout.fillWidth: true
        spacing: 8
        Glyph { text: ct.icon; size: 13; color: Colors.primary }
        Label { text: ct.title; size: 11; font.weight: Font.Bold; Layout.fillWidth: true }
        Label { text: ct.value; size: 11; color: Colors.surfaceVariantText }
    }

    // A ring that sweeps up and pops in, with a counting number, a shimmer running
    // along the arc, and a glowing tip and halo that breathe faster under load
    component Gauge: ColumnLayout {
        id: g
        property int order: 0
        property real value: 0
        property string label: ""
        // Set both to show "used/total" (counting up) instead of a percentage
        property real amount: -1
        property real amountMax: 0
        property color accent: Colors.primary
        readonly property real st: root.stage(order, 0.55)
        readonly property real pop: root.stageBack(order, 0.45)
        readonly property real shownValue: value * st
        spacing: 6
        opacity: Math.min(1, st * 1.6)

        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 100
            implicitHeight: 100
            scale: 0.6 + 0.4 * g.pop

            // Breathing glow
            Rectangle {
                anchors.centerIn: parent
                width: 76; height: 76; radius: 38
                color: g.accent
                opacity: 0.05
                SequentialAnimation on opacity {
                    running: root.open
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.08 + 0.22 * g.value; duration: 2600 - 1800 * g.value; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.04; duration: 2600 - 1800 * g.value; easing.type: Easing.InOutSine }
                }
                SequentialAnimation on scale {
                    running: root.open
                    loops: Animation.Infinite
                    NumberAnimation { to: 1.12; duration: 2600 - 1800 * g.value; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.96; duration: 2600 - 1800 * g.value; easing.type: Easing.InOutSine }
                }
            }

            Ring {
                id: ring
                anchors.fill: parent
                thickness: 9
                value: g.shownValue
                accent: g.accent

                // Arc geometry, same as Ring's: 270° from 135°, `thickness` in from the edge
                readonly property real r: width / 2 - thickness
                readonly property real tipAngle: 135 + 270 * Math.max(0.001, Math.min(1, shown))

                // Shimmer: a short bright band runs along the filled arc, start to tip
                property real sweep: 0
                SequentialAnimation on sweep {
                    running: root.open
                    loops: Animation.Infinite
                    PauseAnimation { duration: 700 }
                    NumberAnimation { from: 0; to: 1; duration: 1100; easing.type: Easing.InOutCubic }
                    PauseAnimation { duration: 1600 }
                }
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    // Fades in and out at the ends of its run
                    opacity: 0.75 * g.st * Math.sin(Math.PI * ring.sweep)
                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: "white"
                        strokeWidth: ring.thickness - 2
                        capStyle: ShapePath.RoundCap
                        PathAngleArc {
                            readonly property real len: Math.min(40, (ring.tipAngle - 135) * 0.6)
                            centerX: ring.width / 2; centerY: ring.height / 2
                            radiusX: ring.r; radiusY: ring.r
                            startAngle: 135 + (ring.tipAngle - 135 - len) * ring.sweep
                            sweepAngle: len
                        }
                    }
                }

                // Glowing tip that breathes, faster under load
                Item {
                    readonly property real a: ring.tipAngle * Math.PI / 180
                    x: ring.width / 2 + ring.r * Math.cos(a) - width / 2
                    y: ring.height / 2 + ring.r * Math.sin(a) - height / 2
                    width: 22; height: 22
                    opacity: g.st

                    Rectangle {
                        anchors.centerIn: parent
                        width: 22; height: 22; radius: 11
                        color: g.accent
                        SequentialAnimation on opacity {
                            running: root.open
                            loops: Animation.Infinite
                            NumberAnimation { from: 0.08; to: 0.4; duration: 1500 - 1000 * Math.min(1, g.value); easing.type: Easing.InOutSine }
                            NumberAnimation { from: 0.4; to: 0.08; duration: 1500 - 1000 * Math.min(1, g.value); easing.type: Easing.InOutSine }
                        }
                        SequentialAnimation on scale {
                            running: root.open
                            loops: Animation.Infinite
                            NumberAnimation { from: 0.6; to: 1; duration: 1500 - 1000 * Math.min(1, g.value); easing.type: Easing.InOutSine }
                            NumberAnimation { from: 1; to: 0.6; duration: 1500 - 1000 * Math.min(1, g.value); easing.type: Easing.InOutSine }
                        }
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 5; height: 5; radius: 2.5
                        color: Qt.lighter(g.accent, 1.6)
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: -2
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: g.amount >= 0 ? `${(g.amount * g.st).toFixed(1)}/${Math.round(g.amountMax)}` : `${Math.round(g.shownValue * 100)}%`
                    size: g.amount >= 0 ? 17 : 22
                    font.weight: Font.Bold
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: g.label
                    size: 9
                    color: Colors.surfaceVariantText
                    font.letterSpacing: 1 + 2 * (1 - g.st)
                }
            }
        }
    }

    ColumnLayout {
        id: body
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        // Header: live dot, title, uptime
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            opacity: root.stage(0)
            transform: Translate { x: (1 - root.stage(0)) * -20 }

            Item {
                implicitWidth: 16
                implicitHeight: 16
                // Ripple
                Rectangle {
                    anchors.centerIn: parent
                    width: 8; height: 8; radius: 4
                    color: "transparent"
                    border.width: 1.5
                    border.color: Colors.primary
                    NumberAnimation on scale {
                        running: root.open
                        loops: Animation.Infinite
                        from: 1; to: 2.4; duration: 1600; easing.type: Easing.OutCubic
                    }
                    NumberAnimation on opacity {
                        running: root.open
                        loops: Animation.Infinite
                        from: 0.9; to: 0; duration: 1600; easing.type: Easing.OutCubic
                    }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 8; height: 8; radius: 4
                    color: Colors.primary
                }
            }
            Label { text: "System"; size: 15; font.weight: Font.Bold; Layout.fillWidth: true }
            Glyph { text: Style.iUptime; size: 12; color: Colors.surfaceVariantText }
            Label { text: SysInfo.uptime; size: 11; color: Colors.surfaceVariantText }
        }

        // CPU, GPU and RAM rings
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            Item { Layout.fillWidth: true }
            Gauge {
                order: 1
                value: SysInfo.cpu / 100
                label: "CPU"
                accent: SysInfo.cpu > 85 || SysInfo.tempCritical ? Colors.error : Colors.primary
            }
            Item { Layout.fillWidth: true }
            Gauge {
                visible: root.gpu !== null
                order: 2
                value: (root.gpu?.util ?? 0) / 100
                label: "GPU"
                accent: (root.gpu?.temp ?? 0) >= 85 ? Colors.error : Colors.secondary
            }
            Item { visible: root.gpu !== null; Layout.fillWidth: true }
            Gauge {
                order: 3
                value: SysInfo.memFrac
                amount: SysInfo.memUsedGiB
                amountMax: SysInfo.memTotalGiB
                label: "RAM · GB"
                accent: SysInfo.memFrac > 0.9 ? Colors.error : Colors.tertiary
            }
            Item { Layout.fillWidth: true }
        }

        Card {
            order: 4
            visible: root.temps.length > 0
            CardTitle {
                icon: Style.iTemp
                title: "Temperatures"
                value: root.hottest ? `max ${root.hottest}°C` : ""
            }

            // One tile per sensor: pops in, counts up, its bar fills; hot ones pulse
            GridLayout {
                Layout.fillWidth: true
                columns: 3
                columnSpacing: 6
                rowSpacing: 6
                Repeater {
                    // A count, not the array: refreshes then update the tiles in place
                    // instead of rebuilding them (which restarted their bars from 0)
                    model: root.temps.length
                    Rectangle {
                        id: tile
                        readonly property var modelData: root.temps[index] ?? ({ name: "", c: 0 })
                        // Glides to each new reading
                        property real c: modelData.c
                        Behavior on c { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                        required property int index
                        readonly property real st: root.stage(5 + index * 0.35, 0.4)
                        readonly property real pop: root.stageBack(5 + index * 0.35, 0.4)
                        readonly property color tint: root.tempColor(modelData.c)
                        readonly property bool hot: modelData.c >= 85
                        Layout.fillWidth: true
                        implicitHeight: 50
                        radius: 10
                        color: Colors.surfaceContainerHigh
                        border.width: 1
                        border.color: Qt.alpha(tint, hot ? 0.9 : 0)
                        opacity: st
                        scale: 0.7 + 0.3 * pop

                        SequentialAnimation on border.color {
                            running: root.open && tile.hot
                            loops: Animation.Infinite
                            ColorAnimation { to: Qt.alpha(tile.tint, 0.15); duration: 700; easing.type: Easing.InOutSine }
                            ColorAnimation { to: Qt.alpha(tile.tint, 0.9); duration: 700; easing.type: Easing.InOutSine }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 2
                            RowLayout {
                                Layout.fillWidth: true
                                Label { text: tile.modelData.name; size: 9; color: Colors.surfaceVariantText; Layout.fillWidth: true }
                                Label {
                                    text: `${Math.round(tile.c * tile.st)}°`
                                    size: 13
                                    font.weight: Font.Bold
                                    color: tile.tint
                                    Behavior on color { ColorAnimation { duration: 400 } }
                                }
                            }
                            Item { Layout.fillHeight: true }
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 4
                                radius: 2
                                color: Colors.surfaceContainerHighest
                                Rectangle {
                                    // 30 °C → empty, 100 °C → full
                                    width: parent.width * tile.st * Math.max(0.03, Math.min(1, (tile.c - 30) / 70))
                                    height: parent.height
                                    radius: 2
                                    color: tile.tint
                                    Behavior on color { ColorAnimation { duration: 400 } }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Click: switch between the CPU graph and the apps using the most CPU
        Card {
            id: cpuCard
            order: 5
            clickable: true
            onClicked: {
                root.cpuTop = !root.cpuTop;
                if (root.cpuTop) cpuInAnim.restart();
            }
            CardTitle {
                icon: Style.iCpu
                title: root.cpuTop ? "Top CPU" : "CPU history"
                value: `${Math.round(SysInfo.cpu)}%`
            }
            Label {
                visible: root.cpuTop && root.topCpu.length === 0
                text: "Measuring…"
                size: 11
                color: Colors.outline
            }
            Repeater {
                // A count, so updates move the bars instead of rebuilding the rows
                model: root.cpuTop ? root.topCpu.length : 0
                ColumnLayout {
                    id: cpuRow
                    required property int index
                    readonly property var modelData: root.topCpu[index] ?? ({ name: "", share: 0 })
                    readonly property real st: root.easeOut(root.clamp01((root.cpuIn - index * 0.1) / 0.5))
                    property real share: modelData.share
                    Behavior on share { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                    Layout.fillWidth: true
                    spacing: 3
                    opacity: st
                    transform: Translate { x: (1 - cpuRow.st) * 26 }
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: cpuRow.modelData.name; size: 11; Layout.fillWidth: true }
                        Label { text: `${(cpuRow.share * 100).toFixed(1)}%`; size: 11; color: Colors.surfaceVariantText }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 4
                        radius: 2
                        color: Colors.surfaceContainerHighest
                        Rectangle {
                            width: parent.width * cpuRow.st * Math.max(0.01, Math.min(1, cpuRow.share))
                            height: parent.height
                            radius: 2
                            color: Colors.primary
                        }
                    }
                }
            }
            Graph {
                id: cpuGraph
                visible: !root.cpuTop
                implicitHeight: 44
                reveal: root.stage(6, 0.5)
                values: SysInfo.cpuHist
                max: 100
                accent: Colors.primary

                // Pulsing dot on the latest sample, once the line has drawn in
                Rectangle {
                    readonly property real v: SysInfo.cpuHist[SysInfo.cpuHist.length - 1] ?? 0
                    x: cpuGraph.width - width / 2 - 1
                    y: cpuGraph.height - 2 - (v / 100) * (cpuGraph.height - 4) - height / 2
                    Behavior on y { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                    width: 7; height: 7; radius: 3.5
                    color: Colors.primary
                    opacity: cpuGraph.reveal > 0.98 ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 7; height: 7; radius: 3.5
                        color: "transparent"
                        border.width: 1.5
                        border.color: Colors.primary
                        NumberAnimation on scale { running: root.open; loops: Animation.Infinite; from: 1; to: 2.6; duration: 1400; easing.type: Easing.OutCubic }
                        NumberAnimation on opacity { running: root.open; loops: Animation.Infinite; from: 0.9; to: 0; duration: 1400; easing.type: Easing.OutCubic }
                    }
                }
            }
        }

        Card {
            order: 6
            CardTitle {
                icon: !SysInfo.online ? Style.iOffline : /^(wl|wlan)/.test(SysInfo.iface) ? Style.iWifi : Style.iEthernet
                title: SysInfo.online ? SysInfo.iface : "Offline"
                value: SysInfo.ipAddr
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                Repeater {
                    model: [[Style.iDown, SysInfo.rxRate, "Download", Colors.cyan],
                            [Style.iUp, SysInfo.txRate, "Upload", Colors.orange]]
                    RowLayout {
                        id: stat
                        required property var modelData
                        spacing: 8
                        Rectangle {
                            implicitWidth: 26
                            implicitHeight: 26
                            radius: 13
                            color: Qt.alpha(stat.modelData[3], 0.2)
                            Glyph {
                                anchors.centerIn: parent
                                text: stat.modelData[0]
                                size: 13
                                color: stat.modelData[3]
                            }
                        }
                        ColumnLayout {
                            spacing: -1
                            Label { text: SysInfo.rate(stat.modelData[1]).trim(); size: 12; font.weight: Font.Bold }
                            Label { text: stat.modelData[2]; size: 8; color: Colors.surfaceVariantText }
                        }
                    }
                }
                Item { Layout.fillWidth: true }
            }
            Graph {
                implicitHeight: 40
                reveal: root.stage(7, 0.5)
                values: SysInfo.rxHist
                values2: SysInfo.txHist
                accent: Colors.cyan
                accent2: Colors.orange
            }
        }

        Card {
            order: 7
            CardTitle {
                icon: Style.iMemory
                title: "Top memory"
                value: `${root.gib(SysInfo.memAvailGiB)} GiB free`
            }
            Repeater {
                model: root.topMem.length
                ColumnLayout {
                    id: proc
                    readonly property var modelData: root.topMem[index] ?? ({ name: "", mib: 0 })
                    property real mib: modelData.mib
                    Behavior on mib { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                    required property int index
                    readonly property real st: root.stage(8 + index * 0.6, 0.35)
                    Layout.fillWidth: true
                    spacing: 3
                    opacity: st
                    transform: Translate { x: (1 - proc.st) * 26 }
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: proc.modelData.name; size: 11; Layout.fillWidth: true }
                        Label { text: root.mib(proc.mib * proc.st); size: 11; color: Colors.surfaceVariantText }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 4
                        radius: 2
                        color: Colors.surfaceContainerHighest
                        Rectangle {
                            width: parent.width * proc.st * Math.min(1, proc.mib / 1024 / Math.max(1, SysInfo.memTotalGiB))
                            height: parent.height
                            radius: 2
                            color: Colors.tertiary
                        }
                    }
                }
            }
        }
    }
}
