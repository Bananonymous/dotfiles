pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// CPU, memory, temperature and network rates, read straight from /proc and /sys
// so polling spawns no processes.
Singleton {
    id: root

    property real cpu: 0
    property string load: ""
    property real memUsedGiB: 0
    property real memTotalGiB: 0
    property real memAvailGiB: 0
    property int tempC: 0
    property string uptime: ""
    readonly property bool tempCritical: tempC >= 80

    property string iface: ""
    property string ipAddr: ""
    property real rxRate: 0
    property real txRate: 0
    readonly property bool online: iface !== ""

    // Last 40 samples (2 s apart) for the dashboard sparklines
    readonly property int histLen: 40
    property var cpuHist: new Array(histLen).fill(0)
    property var rxHist: new Array(histLen).fill(0)
    property var txHist: new Array(histLen).fill(0)
    readonly property real memFrac: memTotalGiB ? memUsedGiB / memTotalGiB : 0

    function push(hist, v) {
        const h = hist.slice(1);
        h.push(v);
        return h;
    }

    property var lastCpu: null
    property var lastNet: null

    function read(view) {
        view.reload();
        return view.text();
    }

    function updateCpu() {
        const f = read(statFile).split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
        const idle = f[3] + f[4];
        const total = f.reduce((a, b) => a + b, 0);
        if (lastCpu) {
            const dt = total - lastCpu.total;
            if (dt > 0) cpu = 100 * (1 - (idle - lastCpu.idle) / dt);
        }
        lastCpu = { idle, total };
        load = read(loadFile).split(" ").slice(0, 3).join(" ");
    }

    function updateMem() {
        const kv = {};
        for (const line of read(memFile).split("\n")) {
            const m = line.match(/^(\w+):\s+(\d+)/);
            if (m) kv[m[1]] = Number(m[2]);
        }
        const gib = 1024 * 1024;
        memTotalGiB = kv.MemTotal / gib;
        memAvailGiB = kv.MemAvailable / gib;
        memUsedGiB = memTotalGiB - memAvailGiB;
    }

    function updateUptime() {
        const s = Math.floor(Number(read(uptimeFile).split(" ")[0]));
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        uptime = d ? `${d}d ${h}h` : h ? `${h}h ${m}m` : `${m}m`;
    }

    function updateTemp() {
        tempC = Math.round(Number(read(tempFile)) / 1000);
    }

    function updateNet() {
        // Default route's interface, then its byte counters
        let dev = "";
        for (const line of read(routeFile).split("\n").slice(1)) {
            const f = line.trim().split(/\s+/);
            if (f[1] === "00000000") { dev = f[0]; break; }
        }
        if (dev !== iface) {
            iface = dev;
            lastNet = null;
            if (dev) ipProc.running = true;
        }
        if (!dev) { rxRate = txRate = 0; return; }

        for (const line of read(netFile).split("\n")) {
            const [name, rest] = line.split(":");
            if (name.trim() !== dev) continue;
            const f = rest.trim().split(/\s+/).map(Number);
            const now = Date.now();
            if (lastNet) {
                const dt = (now - lastNet.t) / 1000;
                rxRate = (f[0] - lastNet.rx) / dt;
                txRate = (f[8] - lastNet.tx) / dt;
            }
            lastNet = { rx: f[0], tx: f[8], t: now };
        }
    }

    // waybar-style "12.3MB/s", right-aligned to a fixed width so the bar doesn't jitter
    function rate(bytes) {
        const units = ["B/s", "kB/s", "MB/s", "GB/s"];
        let i = 0;
        while (bytes >= 1000 && i < units.length - 1) { bytes /= 1000; i++; }
        return ((i ? bytes.toFixed(1) : Math.round(bytes)) + units[i]).padStart(9);
    }

    // Short form for the bar island, e.g. "1.2M", "640K", fixed to 5 characters
    function short(bytes) {
        const units = ["B", "K", "M", "G"];
        let i = 0;
        while (bytes >= 1000 && i < units.length - 1) { bytes /= 1000; i++; }
        return ((i && bytes < 10 ? bytes.toFixed(1) : Math.round(bytes)) + units[i]).padStart(5);
    }

    FileView { id: statFile; path: "/proc/stat"; blockLoading: true }
    FileView { id: uptimeFile; path: "/proc/uptime"; blockLoading: true }
    FileView { id: loadFile; path: "/proc/loadavg"; blockLoading: true }
    FileView { id: memFile; path: "/proc/meminfo"; blockLoading: true }
    // CPU package temperature: the x86_pkg_temp zone, whose number differs per machine
    FileView { id: tempFile; path: "/sys/class/thermal/thermal_zone1/temp"; blockLoading: true }
    Process {
        running: true
        command: ["sh", "-c", "grep -l '^x86_pkg_temp$' /sys/class/thermal/thermal_zone*/type | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const zone = text.trim().replace(/\/type$/, "");
                if (zone) { tempFile.path = zone + "/temp"; root.updateTemp(); }
            }
        }
    }
    FileView { id: routeFile; path: "/proc/net/route"; blockLoading: true }
    FileView { id: netFile; path: "/proc/net/dev"; blockLoading: true }

    Process {
        id: ipProc
        command: ["ip", "-4", "-o", "addr", "show", "dev", root.iface]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/inet (\S+)/);
                root.ipAddr = m ? m[1] : "";
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.updateCpu();
            root.updateNet();
            root.cpuHist = root.push(root.cpuHist, root.cpu);
            root.rxHist = root.push(root.rxHist, root.rxRate);
            root.txHist = root.push(root.txHist, root.txRate);
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.updateMem();
            root.updateTemp();
            root.updateUptime();
        }
    }
}
