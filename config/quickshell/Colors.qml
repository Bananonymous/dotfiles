pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Material You palette written by matugen (~/.config/matugen/templates/quickshell.json).
// The file is watched; on change every color blends from old to new over fadeMs.
// matugen's on_* roles are named *Text here (on_surface -> surfaceText): QML would
// parse a property called onSurface as a signal handler.
// (One shared animation of `t` drives the fade: `Behavior` inside a Singleton
// crashes Quickshell 0.3.2.)
Singleton {
    id: root

    readonly property int fadeMs: 900

    // Catppuccin Mocha until matugen has written colors.json
    property var target: ({
        background: "#1e1e2e",
        surface: "#1e1e2e",
        surface_dim: "#181825",
        surface_bright: "#45475a",
        surface_container_lowest: "#11111b",
        surface_container_low: "#181825",
        surface_container: "#1e1e2e",
        surface_container_high: "#313244",
        surface_container_highest: "#45475a",
        surface_variant: "#313244",
        on_surface: "#cdd6f4",
        on_surface_variant: "#a6adc8",
        outline: "#6c7086",
        outline_variant: "#45475a",
        shadow: "#000000",
        scrim: "#000000",
        inverse_surface: "#cdd6f4",
        inverse_on_surface: "#1e1e2e",
        primary: "#89b4fa",
        on_primary: "#1e1e2e",
        primary_container: "#313244",
        on_primary_container: "#cdd6f4",
        secondary: "#b4befe",
        on_secondary: "#1e1e2e",
        secondary_container: "#313244",
        on_secondary_container: "#cdd6f4",
        tertiary: "#cba6f7",
        on_tertiary: "#1e1e2e",
        tertiary_container: "#313244",
        on_tertiary_container: "#cdd6f4",
        error: "#f38ba8",
        on_error: "#1e1e2e",
        error_container: "#45475a",
        on_error_container: "#f38ba8",
        red: "#f38ba8",
        orange: "#fab387",
        yellow: "#f9e2af",
        green: "#a6e3a1",
        cyan: "#94e2d5",
        blue: "#89b4fa",
        magenta: "#cba6f7"
    })
    property var origin: target
    property real t: 1
    property bool primed: false

    function blend(name) {
        const a = Qt.color(origin[name] ?? target[name]);
        const b = Qt.color(target[name]);
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }

    function apply(text) {
        let next;
        try { next = JSON.parse(text); } catch (e) { return; }
        delete next.mode;
        // Start from whatever is on screen now, even mid-fade
        const now = {};
        for (const name in target) now[name] = blend(name).toString();
        origin = now;
        target = Object.assign({}, target, next);
        // First read at startup snaps; later wallpaper changes fade
        if (primed) fade.restart();
        else t = 1;
        primed = true;
    }

    readonly property color background: blend("background")
    readonly property color surface: blend("surface")
    readonly property color surfaceDim: blend("surface_dim")
    readonly property color surfaceBright: blend("surface_bright")
    readonly property color surfaceContainerLowest: blend("surface_container_lowest")
    readonly property color surfaceContainerLow: blend("surface_container_low")
    readonly property color surfaceContainer: blend("surface_container")
    readonly property color surfaceContainerHigh: blend("surface_container_high")
    readonly property color surfaceContainerHighest: blend("surface_container_highest")
    readonly property color surfaceVariant: blend("surface_variant")
    readonly property color surfaceText: blend("on_surface")
    readonly property color surfaceVariantText: blend("on_surface_variant")
    readonly property color outline: blend("outline")
    readonly property color outlineVariant: blend("outline_variant")
    readonly property color shadow: blend("shadow")
    readonly property color scrim: blend("scrim")
    readonly property color inverseSurface: blend("inverse_surface")
    readonly property color inverseOnSurface: blend("inverse_on_surface")
    readonly property color primary: blend("primary")
    readonly property color primaryText: blend("on_primary")
    readonly property color primaryContainer: blend("primary_container")
    readonly property color primaryContainerText: blend("on_primary_container")
    readonly property color secondary: blend("secondary")
    readonly property color secondaryText: blend("on_secondary")
    readonly property color secondaryContainer: blend("secondary_container")
    readonly property color secondaryContainerText: blend("on_secondary_container")
    readonly property color tertiary: blend("tertiary")
    readonly property color tertiaryText: blend("on_tertiary")
    readonly property color tertiaryContainer: blend("tertiary_container")
    readonly property color tertiaryContainerText: blend("on_tertiary_container")
    readonly property color error: blend("error")
    readonly property color errorText: blend("on_error")
    readonly property color errorContainer: blend("error_container")
    readonly property color errorContainerText: blend("on_error_container")
    readonly property color red: blend("red")
    readonly property color orange: blend("orange")
    readonly property color yellow: blend("yellow")
    readonly property color green: blend("green")
    readonly property color cyan: blend("cyan")
    readonly property color blue: blend("blue")
    readonly property color magenta: blend("magenta")

    NumberAnimation {
        id: fade
        target: root
        property: "t"
        from: 0
        to: 1
        duration: root.fadeMs
        easing.type: Easing.InOutQuad
    }

    FileView {
        path: Quickshell.shellPath("colors.json")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.apply(text())
    }
}
