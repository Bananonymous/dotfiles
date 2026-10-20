pragma Singleton
import QtQuick
import Quickshell
import "../.." as Root

// Serpantinum's theme names, filled from our matugen palette using the same role
// mapping as its own matugen template (serpantinum_matugen_colors.json.template).
Singleton {
    readonly property string fontFamily: "Adwaita Mono"
    readonly property string iconFont: "Hack Nerd Font Propo"
    readonly property int borderRadius: 10
    readonly property int clampedBorderRadius: borderRadius

    readonly property color base: Root.Colors.surfaceContainerLowest
    readonly property color mantle: Root.Colors.surfaceContainerLow
    readonly property color crust: Root.Colors.surface
    readonly property color surface: Root.Colors.surface
    readonly property color text: Root.Colors.surfaceText
    readonly property color subtext0: Root.Colors.surfaceVariantText
    readonly property color subtext1: Root.Colors.outline
    readonly property color subtext: Root.Colors.surfaceVariantText
    readonly property color surface0: Root.Colors.surfaceContainer
    readonly property color surface1: Root.Colors.surfaceContainerHigh
    readonly property color surface2: Root.Colors.surfaceContainerHighest
    readonly property color overlay0: Root.Colors.inverseSurface
    readonly property color overlay1: Root.Colors.inverseSurface
    readonly property color overlay2: Root.Colors.inverseSurface
    readonly property color blue: Root.Colors.primary
    readonly property color sapphire: Root.Colors.primaryContainer
    readonly property color peach: Root.Colors.tertiary
    readonly property color green: Root.Colors.secondary
    readonly property color red: Root.Colors.error
    readonly property color mauve: Root.Colors.primary
    readonly property color pink: Root.Colors.tertiaryContainer
    readonly property color yellow: Root.Colors.secondaryContainer
    readonly property color maroon: Root.Colors.errorContainer
    readonly property color teal: Root.Colors.secondary
    readonly property color lavender: Root.Colors.secondary
}
