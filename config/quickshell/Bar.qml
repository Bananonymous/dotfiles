import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.SystemTray
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Wayland
import "serp" as Serp

// One bar per screen: a row of floating pills, each opening its own drop-down panel.
// The layer surface is tall enough for the panels, but its input mask only covers the
// pills and the open panel, so clicks elsewhere reach the windows below.
PanelWindow {
    id: bar

    required property ShellScreen modelData
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(modelData)
    readonly property bool focusedScreen: Hyprland.focusedMonitor === monitor

    // "", "media", "clock", "orbit", "power", "screentime", "notifs", "sys"
    property string openPanel: ""
    property string orbitTab: Net.kind === "none" && btDevice ? "bluetooth" : "wifi"

    readonly property BluetoothDevice btDevice: Bluetooth.defaultAdapter?.devices.values.find(d => d.connected) ?? null

    function toggle(name) { openPanel = openPanel === name ? "" : name; }

    screen: modelData
    WlrLayershell.namespace: "quickshell-bar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: openPanel ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    anchors {
        top: true
        left: true
        right: true
    }
    margins {
        top: 6
        left: 8
        right: 8
    }
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: Style.barHeight
    implicitHeight: Math.min(1000, modelData.height - 40)    // room for the tallest panel (system)
    color: "transparent"

    mask: Region {
        Region { item: leftGroup }
        Region { item: centerGroup }
        Region { item: rightGroup }
        Region { item: panelHit }
    }

    HyprlandFocusGrab {
        windows: [bar]
        active: bar.openPanel !== ""
        onCleared: bar.openPanel = ""
    }

    IdleInhibitor {
        window: bar
        enabled: Style.idleInhibit
    }

    Connections {
        target: Style
        function onPanelRequested(name) { if (bar.focusedScreen) bar.toggle(name); }
        function onEqPresetRequested(name) {
            if (!bar.focusedScreen) return;
            if (bar.openPanel === "media") mediaPanel.applyPresetOptimistically(name);
            else Eq.usePreset(name);
        }
    }

    Item {
        anchors.fill: parent
        focus: bar.openPanel !== ""
        Keys.onEscapePressed: bar.openPanel = ""
    }

    // ── Left: search, notifications, workspaces, media ──────────────────────────
    RowLayout {
        id: leftGroup
        anchors.left: parent.left
        anchors.top: parent.top
        spacing: 6

        BarPill {
            Chip {
                icon: Style.iSearch
                iconSize: 14
                padding: 8
                onClicked: Quickshell.execDetached(["rofi", "-show", "drun"])
            }
        }
        BarPill {
            id: bellPill
            Chip {
                icon: Notifs.dnd ? Style.iBellOff : Style.iBell
                iconSize: 15
                padding: 8
                iconColor: Notifs.count && !Notifs.dnd ? Colors.primary : Colors.surfaceText
                onClicked: b => b === Qt.RightButton ? (Notifs.dnd = !Notifs.dnd) : bar.toggle("notifs")

                Rectangle {
                    visible: Notifs.count > 0 && !Notifs.dnd
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 4
                    width: 7; height: 7; radius: 3.5
                    color: Colors.error
                }
            }
        }
        BarPill {
            padding: 4
            Workspaces { monitor: bar.monitor }
        }
        BarPill {
            id: mediaPill
            visible: Media.active
            padding: 8
            spacing: 8

            // Cover + title/time; click opens the media panel
            MouseArea {
                id: mediaInfo
                Layout.preferredWidth: infoRow.implicitWidth
                Layout.preferredHeight: Style.barHeight
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: bar.toggle("media")

                Row {
                    id: infoRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    transformOrigin: Item.Left
                    scale: mediaInfo.containsMouse ? 1.01 : 1.0
                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }

                    ClippingRectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28; height: 28; radius: 10
                        color: Colors.surfaceContainerHighest
                        border.width: 1
                        border.color: Media.playing ? Colors.primary : Colors.surfaceContainerHighest
                        Behavior on border.color { ColorAnimation { duration: 250 } }

                        Glyph {
                            anchors.centerIn: parent
                            visible: Media.art === ""
                            text: Style.iMusic
                            size: 14
                            color: Colors.surfaceVariantText
                        }
                        Image {
                            anchors.fill: parent
                            source: Media.art
                            sourceSize: Qt.size(56, 56)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 120
                        spacing: -2

                        Marquee {
                            width: parent.width
                            text: Media.title
                            color: Colors.surfaceText
                            font.family: Style.font
                            font.pixelSize: 12
                            font.weight: Font.Black
                            active: Media.playing
                        }
                        Text {
                            width: parent.width
                            text: Media.length > 0 ? `${Media.fmt(Media.position)} / ${Media.fmt(Media.length)}` : Media.artist
                            color: Colors.surfaceVariantText
                            font.family: Style.font
                            font.pixelSize: 10
                            font.weight: Font.Black
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Row {
                spacing: 4
                IconButton {
                    icon: Style.iPrev
                    iconSize: 13
                    onClicked: Media.player?.previous()
                }
                IconButton {
                    icon: Media.playing ? Style.iPause : Style.iPlay
                    iconSize: 15
                    textColor: Colors.surfaceText
                    hoverTextColor: Colors.secondary
                    onClicked: Media.player?.togglePlaying()
                }
                IconButton {
                    icon: Style.iNext
                    iconSize: 13
                    onClicked: Media.player?.next()
                }
            }
        }
    }

    // ── Center: clock + weather ─────────────────────────────────────────────────
    BarPill {
        id: centerGroup
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        padding: 14
        spacing: 18

        SystemClock {
            id: clock
            precision: SystemClock.Seconds
        }

        MouseArea {
            Layout.preferredWidth: clockCol.implicitWidth
            Layout.preferredHeight: Style.barHeight
            cursorShape: Qt.PointingHandCursor
            onClicked: bar.toggle("clock")

            Column {
                id: clockCol
                anchors.verticalCenter: parent.verticalCenter
                spacing: -2

                Text {
                    text: Qt.locale().toString(clock.date, "HH:mm:ss")
                    color: Colors.primary
                    font.family: Style.font
                    font.pixelSize: 15
                    font.weight: Font.Black
                }
                // The date types itself in, one letter at a time
                Text {
                    id: dateText
                    readonly property string full: Qt.locale().toString(clock.date, "dddd, d MMMM")
                    property int shown: 0
                    onFullChanged: if (shown > full.length) shown = full.length
                    text: full.substring(0, shown)
                    color: Colors.surfaceVariantText
                    font.family: Style.font
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.capitalization: Font.Capitalize

                    Timer {
                        interval: 30
                        running: dateText.shown < dateText.full.length
                        repeat: true
                        onTriggered: dateText.shown++
                    }
                }
            }
        }

        MouseArea {
            visible: Weather.ready
            Layout.preferredWidth: weatherRow.implicitWidth
            Layout.preferredHeight: Style.barHeight
            cursorShape: Qt.PointingHandCursor
            onClicked: bar.toggle("clock")

            Row {
                id: weatherRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Weather.data?.icon ?? ""
                    size: 20
                    color: Qt.tint(Colors.surfaceText, Qt.alpha(Colors.primary, 0.4))
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: `${Weather.data?.temp ?? ""}°C`
                    color: Colors.tertiary
                    font.family: Style.font
                    font.pixelSize: 15
                    font.weight: Font.Black
                }
            }
        }
    }

    // ── Right: tray, layout, network, bluetooth, volume, power ─────────────────
    RowLayout {
        id: rightGroup
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 6

        BarPill {
            visible: SystemTray.items.values.length > 0
            padding: 6
            Tray { id: tray }
        }

        // Pending updates (pacman + AUR). Click: update everything in a terminal;
        // right click: check again. Pulses while the update terminal is open.
        BarPill {
            id: updatesPill
            padding: 5
            Chip {
                id: updatesChip
                icon: Style.iUpdates
                text: Updates.upgrading ? "…" : Updates.total > 0 ? Updates.total : ""
                fontSize: 11
                iconSize: 14
                padding: 8
                iconColor: Updates.upgrading || Updates.total > 0 ? Colors.primary : Colors.outline
                tooltip: Updates.upgrading ? "Updating…"
                    : !Updates.checked ? "Checking for updates…"
                    : Updates.total === 0 ? "Up to date"
                    : `${Updates.pacman} pacman · ${Updates.aur} AUR — click to update`
                onClicked: b => b === Qt.RightButton ? Updates.refresh() : Updates.runUpgrade()

                SequentialAnimation on opacity {
                    running: Updates.upgrading
                    loops: Animation.Infinite
                    onStopped: updatesChip.opacity = 1
                    NumberAnimation { to: 0.45; duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
                }
            }
        }

        // RAM at a glance; CPU, network and the rest are in the system panel
        BarPill {
            id: sysPill
            padding: 5
            Chip {
                icon: Style.iMemory
                text: `${SysInfo.memUsedGiB.toFixed(1)} / ${Math.round(SysInfo.memTotalGiB)} GB`
                fontSize: 11
                iconSize: 14
                padding: 8
                iconColor: SysInfo.memFrac > 0.9 ? Colors.error : Colors.tertiary
                tooltip: `RAM · ${Math.round(SysInfo.memFrac * 100)}% used`
                onClicked: bar.toggle("sys")
            }
        }

        BarPill {
            id: statusPill
            padding: 5
            spacing: 4

            // Roll the wallpaper (and with it, via matugen, the whole palette)
            Chip {
                id: wallChip
                icon: Style.iWallpaper
                iconSize: 14
                padding: 8
                tooltip: "Next wallpaper"
                onClicked: {
                    spin.restart();
                    Quickshell.execDetached([Quickshell.shellPath("scripts/next-wallpaper.sh")]);
                }
                // One full turn with a little overshoot on each roll
                RotationAnimation {
                    id: spin
                    target: wallChip.children[0].children[0]
                    from: 0; to: 360
                    duration: 700
                    easing.type: Easing.OutBack
                }
            }

            // Filled "connection" chips, like the reference
            component LinkChip: Chip {
                property bool on: true
                fontSize: 11
                iconSize: 13
                padding: 9
                color: on ? Colors.primary : (hovered ? hoverBg : "transparent")
                hoverBg: on ? Colors.primary : Colors.surfaceContainerHighest
                fg: on ? Colors.primaryText : Colors.surfaceVariantText
                Behavior on color { ColorAnimation { duration: 200 } }
            }

            LinkChip {
                id: netChip
                on: Net.kind !== "none"
                icon: Net.kind === "wifi" ? Style.iWifi : Net.kind === "ethernet" ? Style.iEthernet : Style.iWifiOff
                text: Net.kind === "wifi" ? (Net.name.length > 12 ? Net.name.slice(0, 11) + "…" : Net.name)
                    : Net.kind === "ethernet" ? "Wired" : "Offline"
                onClicked: { bar.orbitTab = "wifi"; bar.openPanel = bar.openPanel === "orbit" && bar.orbitTab === "wifi" ? "" : "orbit"; }
            }
            LinkChip {
                id: btChip
                visible: Bluetooth.defaultAdapter !== null
                on: bar.btDevice !== null
                icon: Bluetooth.defaultAdapter?.enabled ? Style.iBluetooth : Style.iBluetoothOff
                text: bar.btDevice ? (bar.btDevice.name.length > 12 ? bar.btDevice.name.slice(0, 11) + "…" : bar.btDevice.name) : ""
                onClicked: { bar.orbitTab = "bluetooth"; bar.openPanel = bar.openPanel === "orbit" && bar.orbitTab === "bluetooth" ? "" : "orbit"; }
            }

            Chip {
                icon: Audio.icon
                text: Audio.muted ? "" : Math.round(Audio.volume * 100)
                iconSize: 13
                fontSize: 11
                padding: 7
                iconColor: Audio.muted ? Colors.outline : Colors.surfaceText
                tooltip: Audio.sink?.description ?? ""
                onClicked: b => b === Qt.RightButton ? Quickshell.execDetached(["pavucontrol", "-t", "3"]) : Audio.toggleMute()
                onScrolled: d => Audio.setVolume(Audio.volume + d * 0.02)
            }

            Chip {
                id: powerChip
                icon: Power.hasBattery ? (Power.charging ? Style.iCharging : Style.iBattery) : Style.iPower
                text: Power.hasBattery ? Math.round(Power.level * 100) : ""
                iconSize: 13
                fontSize: 11
                padding: 7
                iconColor: Power.hasBattery && Power.level < 0.15 && !Power.charging ? Colors.error : Colors.surfaceText
                onClicked: bar.toggle("power")
            }
        }
    }

    // ── Panels ─────────────────────────────────────────────────────────────────
    Item {
        id: panels
        anchors.fill: parent
        anchors.topMargin: Style.barHeight + 8

        readonly property Item current: ({
            media: mediaPanel, clock: clockPanel, orbit: orbitPanel,
            power: powerPanel, screentime: screenPanel, notifs: notifPanel, sys: sysPanel
        })[bar.openPanel] ?? null

        // Input area for the open panel. The mask keeps pointing at this one item and only
        // its geometry changes: a Region whose `item` is swapped doesn't update the mask.
        Item {
            id: panelHit
            x: panels.current?.x ?? 0
            y: panels.current?.y ?? 0
            width: panels.current?.width ?? 0
            height: panels.current?.height ?? 0
        }

        // x of a bar item's center, in this item's coordinates
        function centerOf(item) { return item.mapToItem(panels, item.width / 2, 0).x; }

        // Media popup ported from Serpantinum (serp/media), at its own size and spot
        Serp.MusicPopup {
            id: mediaPanel
            readonly property bool open: bar.openPanel === "media"
            x: 0
            width: 625
            height: 565
            onOpenChanged: {
                if (open) visible = true;
                else if (visible) startExit(() => visible = false);
            }
        }
        // Calendar + weather popup ported from Serpantinum (serp/calendar); it runs its
        // own entrance, and on close plays its exit before hiding.
        Serp.CalendarPopup {
            id: clockPanel
            readonly property bool open: bar.openPanel === "clock"
            anchors.horizontalCenter: parent.horizontalCenter
            onOpenChanged: {
                if (open) visible = true;
                else if (visible) startExit(() => visible = false);
            }
        }
        OrbitPanel {
            id: orbitPanel
            open: bar.openPanel === "orbit"
            tab: bar.orbitTab
            onTabSwitched: t => bar.orbitTab = t
            anchors.right: parent.right
            pivotX: panels.centerOf(bar.orbitTab === "wifi" ? netChip : btChip) - x
        }
        SysPanel {
            id: sysPanel
            open: bar.openPanel === "sys"
            // From layout positions (not mapToItem) so it follows the island as the bar changes
            readonly property real anchorX: rightGroup.x + sysPill.x + sysPill.width / 2
            x: Math.max(0, Math.min(panels.width - width, anchorX - width / 2))
            pivotX: anchorX - x
        }
        PowerPanel {
            id: powerPanel
            open: bar.openPanel === "power"
            anchors.right: parent.right
            pivotX: panels.centerOf(powerChip) - x
            onShowScreenTime: bar.openPanel = "screentime"
            onClose: bar.openPanel = ""
        }
        ScreenTimePanel {
            id: screenPanel
            open: bar.openPanel === "screentime"
            anchors.horizontalCenter: parent.horizontalCenter
            pivotX: width / 2
        }
        NotifPanel {
            id: notifPanel
            open: bar.openPanel === "notifs"
            x: Math.max(0, panels.centerOf(bellPill) - 60)
            pivotX: panels.centerOf(bellPill) - x
        }
    }
}
