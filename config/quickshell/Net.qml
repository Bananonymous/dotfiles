pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// NetworkManager state via nmcli: what we're connected through, Wi-Fi details and scan list.
Singleton {
    id: root

    // "wifi" | "ethernet" | "none"
    property string kind: "none"
    property string device: ""
    property string name: ""            // SSID or connection name
    property int signal: 0
    property string freq: ""
    property string security: ""
    property int linkSpeed: 0           // Mb/s, ethernet
    property bool wifiEnabled: true
    property bool hasWifi: false
    property var networks: []           // [{ ssid, signal, secure, active }]
    property bool detailed: false       // panel open: poll faster and scan

    readonly property string ip: SysInfo.ipAddr.split("/")[0]

    function refresh() { if (!devProc.running) devProc.running = true; }
    function scan() { Quickshell.execDetached(["nmcli", "dev", "wifi", "rescan"]); }
    function setWifi(on) {
        wifiEnabled = on;
        Quickshell.execDetached(["nmcli", "radio", "wifi", on ? "on" : "off"]);
        refreshLater.restart();
    }
    // Known networks connect directly; new secured ones open nmtui to ask for the password
    function connect(ssid, secure, known) {
        if (secure && !known)
            Quickshell.execDetached(["kitty", "--class", "nmtui", "-e", "nmtui", "connect", ssid]);
        else
            Quickshell.execDetached(["nmcli", "dev", "wifi", "connect", ssid]);
        refreshLater.restart();
    }

    Timer { id: refreshLater; interval: 2500; onTriggered: root.refresh() }

    // Which device carries the connection (wifi preferred if both are up)
    Process {
        id: devProc
        command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "dev"]
        stdout: StdioCollector {
            onStreamFinished: {
                let wifi = null, eth = null;
                root.hasWifi = false;
                for (const line of text.trim().split("\n")) {
                    const [dev, type, state, conn] = line.split(":");
                    if (type === "wifi") root.hasWifi = true;
                    if (state !== "connected") continue;
                    if (type === "wifi" && !wifi) wifi = { dev, conn };
                    if (type === "ethernet" && !eth) eth = { dev, conn };
                }
                const pick = wifi ?? eth;
                root.kind = wifi ? "wifi" : eth ? "ethernet" : "none";
                root.device = pick?.dev ?? "";
                root.name = pick?.conn ?? "";
                if (root.hasWifi) wifiProc.running = true;
                if (eth && !wifi) speedFile.reload();
                radioProc.running = true;
            }
        }
    }

    Process {
        id: radioProc
        command: ["nmcli", "radio", "wifi"]
        stdout: StdioCollector { onStreamFinished: root.wifiEnabled = text.trim() === "enabled" }
    }

    Process {
        id: wifiProc
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,FREQ,SECURITY", "dev", "wifi", "list", "--rescan", "no"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = new Map();
                for (const line of text.trim().split("\n")) {
                    if (!line) continue;
                    // SSIDs may contain escaped colons
                    const f = line.replace(/\\:/g, "\u0001").split(":").map(s => s.replace(/\u0001/g, ":"));
                    const [inUse, ssid, sig, freq, sec] = f;
                    if (!ssid) continue;
                    const n = { ssid, signal: Number(sig), secure: !!sec && sec !== "--", active: inUse === "*", freq, security: sec };
                    if (n.active) {
                        root.signal = n.signal;
                        root.freq = freq;
                        root.security = sec;
                        root.name = ssid;
                    }
                    const prev = seen.get(ssid);
                    if (!prev || n.active || n.signal > prev.signal) seen.set(ssid, n);
                }
                root.networks = [...seen.values()].sort((a, b) => b.active - a.active || b.signal - a.signal);
            }
        }
    }

    FileView {
        id: speedFile
        path: root.device ? `/sys/class/net/${root.device}/speed` : ""
        blockLoading: true
        printErrors: false
        onLoaded: root.linkSpeed = Number(text()) || 0
    }

    Timer {
        interval: root.detailed ? 5000 : 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
