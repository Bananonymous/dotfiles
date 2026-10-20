pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Battery (laptop), power profile and backlight. On a desktop the battery parts stay hidden.
Singleton {
    id: root

    readonly property UPowerDevice battery: UPower.displayDevice
    readonly property bool hasBattery: battery?.isLaptopBattery ?? false
    // UPower reports 0..1 in Quickshell; guard against 0..100 just in case
    readonly property real level: {
        const p = battery?.percentage ?? 0;
        return p > 1 ? p / 100 : p;
    }
    readonly property bool charging: battery?.state === UPowerDeviceState.Charging
    readonly property bool full: battery?.state === UPowerDeviceState.FullyCharged
    readonly property bool onBattery: UPower.onBattery
    // Seconds until empty (discharging) or full (charging)
    readonly property real eta: charging ? (battery?.timeToFull ?? 0) : (battery?.timeToEmpty ?? 0)

    // "performance" | "balanced" | "power-saver"
    readonly property string profile: PowerProfiles.profile === PowerProfile.Performance ? "performance"
        : PowerProfiles.profile === PowerProfile.PowerSaver ? "power-saver" : "balanced"
    readonly property bool hasPerformance: PowerProfiles.hasPerformanceProfile

    function setProfile(name) {
        PowerProfiles.profile = name === "performance" ? PowerProfile.Performance
            : name === "power-saver" ? PowerProfile.PowerSaver : PowerProfile.Balanced;
    }

    // Backlight via brightnessctl (only present on the laptop)
    property bool hasBacklight: false
    property real brightness: 0

    function setBrightness(v) {
        brightness = Math.max(0.01, Math.min(1, v));
        Quickshell.execDetached(["brightnessctl", "-q", "set", `${Math.round(brightness * 100)}%`]);
    }

    Process {
        id: blProc
        running: true
        command: ["sh", "-c", "command -v brightnessctl >/dev/null && ls /sys/class/backlight | grep -q . && brightnessctl -m info"]
        stdout: StdioCollector {
            onStreamFinished: {
                // name,class,current,percent,max
                const f = text.trim().split(",");
                root.hasBacklight = f.length >= 4;
                if (root.hasBacklight) root.brightness = parseInt(f[3]) / 100;
            }
        }
    }
    Timer {
        interval: 5000
        running: root.hasBacklight
        repeat: true
        onTriggered: blProc.running = true
    }
}
