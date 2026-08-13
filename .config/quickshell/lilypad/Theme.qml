// Theme.qml — the lilypad token board.
// Raw matugen palette (m3-prefixed: QML forbids on*-named properties, which is
// why end-4 prefixes too) -> layers (L0-L3, derived hover/active/border) ->
// status + graph tokens -> geometry/type. matugen writes colors.json on every
// wallpaper change (lilypad template in matugen config.toml); the FileView
// below patches the palette live — no shell bounce for a palette swap. The
// statics are the boot fallback (pond set) and hold until the first matugen
// run lands. Status hues (green/amber/red/blue/purple) are deliberately FIXED:
// alarm semantics stay legible no matter what the wallpaper does.
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // ---- raw palette (mutable: patched from matugen JSON; pond fallbacks) ----
    property color m3background: "#05090a"
    property color m3onBackground: "#e6f0ee"
    property color m3surfaceDim: "#05090a"
    property color m3surfaceBright: "#1a292b"
    property color m3surfaceContainerLowest: "#080f10"
    property color m3surfaceContainerLow: "#0b1214"
    property color m3surfaceContainer: "#101b1d"
    property color m3surfaceContainerHigh: "#152224"
    property color m3surfaceContainerHighest: "#1a292b"
    property color m3onSurface: "#e6f0ee"
    property color m3onSurfaceVariant: "#a8bdb9"
    property color m3outline: "#6b807c"
    property color m3outlineVariant: "#2a3a3c"
    property color m3primary: "#4ade80"
    property color m3onPrimary: "#052e12"
    property color m3primaryContainer: "#14532d"
    property color m3onPrimaryContainer: "#bbf7d0"
    property color m3inversePrimary: "#166534"
    property color m3secondary: "#5cc8e8"
    property color m3onSecondary: "#062a35"
    property color m3secondaryContainer: "#0e4a5e"
    property color m3onSecondaryContainer: "#c9eef9"
    property color m3tertiary: "#a78bfa"
    property color m3onTertiary: "#241548"
    property color m3tertiaryContainer: "#3b2a6b"
    property color m3onTertiaryContainer: "#e4dcfd"
    property color m3error: "#f87171"
    property color m3onError: "#450a0a"
    property color m3errorContainer: "#7f1d1d"
    property color m3onErrorContainer: "#fecaca"
    property color m3inverseSurface: "#e6f0ee"
    property color m3inverseOnSurface: "#101b1d"
    property color m3shadow: "#000000"
    property color m3scrim: "#000000"
    property color m3sourceColor: "#4ade80"

    // ---- layers: L0 ground, L1 section/pill, L2 chip, L3 popup/raised ----
    readonly property color l0: m3background
    readonly property color l0Text: m3onBackground
    readonly property color l0Hover: mix(l0, l0Text, 0.92)
    readonly property color l0Active: mix(l0, l0Text, 0.85)
    readonly property color l0Border: mix(m3outlineVariant, l0, 0.4)

    readonly property color l1: m3surfaceContainerLow
    readonly property color l1Text: m3onSurfaceVariant
    readonly property color l1Hover: mix(l1, l1Text, 0.92)
    readonly property color l1Active: mix(l1, l1Text, 0.85)
    readonly property color l1Border: mix(m3outlineVariant, l1, 0.4)

    readonly property color l2: m3surfaceContainer
    readonly property color l2Text: m3onSurface
    readonly property color l2Hover: mix(l2, l2Text, 0.90)
    readonly property color l2Active: mix(l2, l2Text, 0.80)
    readonly property color l2Border: mix(m3outlineVariant, l2, 0.4)

    readonly property color l3: m3surfaceContainerHigh
    readonly property color l3Text: m3onSurface
    readonly property color l3Hover: mix(l3, l3Text, 0.90)
    readonly property color l3Active: mix(l3, l3Text, 0.80)
    readonly property color l3Border: mix(m3outlineVariant, l3, 0.4)

    // ---- status: FIXED hues, wallpaper-proof ----
    readonly property color green: "#4ade80"
    readonly property color amber: "#fbbf24"
    readonly property color red: "#f87171"
    readonly property color blue: "#5cc8e8"
    readonly property color purple: "#a78bfa"
    readonly property color ok: green
    readonly property color warn: amber
    readonly property color crit: red
    readonly property color info: blue

    // waybar-class convention, promoted: critical/urgent -> crit,
    // warning/disconnected -> warn, charging/plugged/ok -> ok
    function stateColor(cls) {
        if (cls === "critical" || cls === "urgent") return crit
        if (cls === "warning" || cls === "disconnected") return warn
        if (cls === "charging" || cls === "plugged" || cls === "ok") return ok
        if (cls === "info") return info
        return text
    }
    // threshold mapping for gauges/meters (defaults tunable per module)
    function valueToColor(v, warnLevel, critLevel) {
        const w = warnLevel === undefined ? root.warnAt : warnLevel
        const c = critLevel === undefined ? root.critAt : critLevel
        return v >= c ? crit : v >= w ? warn : ok
    }

    // ---- graph tokens: one look for every meter/gauge/spark ----
    // stacked thin MeterBars are the bar-level default; gauges live in popups
    readonly property int meterHeight: 6
    readonly property int meterRadius: 3
    readonly property int meterWidth: 96
    readonly property int meterGap: 4      // vertical gap inside stacked meter pairs
    readonly property color track: alpha(m3onSurface, 0.12)
    readonly property int gaugeSize: 26
    readonly property int gaugeStroke: 3
    readonly property real sparkStroke: 1.5
    readonly property color sparkFill: alpha(m3primary, 0.15)
    readonly property int warnAt: 70
    readonly property int critAt: 90

    // ---- legacy aliases (v1 consumers; migrate at leisure) ----
    readonly property color bg: m3background
    readonly property color surface: m3surfaceContainerLow
    readonly property color elevated: m3surfaceContainer
    readonly property color text: m3onSurface
    readonly property color text2: m3onSurfaceVariant
    readonly property color text3: m3outline
    readonly property color accent: m3primary
    readonly property color border: alpha(m3onSurface, 0.09)
    readonly property color borderStrong: alpha(m3onSurface, 0.17)

    // ---- geometry + type ----
    readonly property real islandAlpha: 0.86   // tile glass density (0.62 -> 0.78 -> 0.86, Jay-tuned; hypr blurs behind it)
    // near-black tile ground, faint palette tint (Jay: pills darker than surface tones)
    readonly property color tileBase: mix("#000000", m3background, 0.55)
    readonly property int barHeight: 52        // island height — roomy, uses the inside space
    readonly property int islandMargin: 4      // vertical ring: tile to screen-top / to windows
    readonly property int barSideMargin: 8     // = hypr gaps_out, so end tiles align with window borders
    readonly property int islandRadius: 20
    readonly property int radius: 10
    readonly property int chipRadius: 8
    readonly property int pillRadius: 999
    readonly property int pad: 8
    readonly property int padS: 4
    readonly property int padL: 12
    readonly property int gap: 6
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property string fontMono: "JetBrainsMono Nerd Font"
    readonly property int fontSize: 15
    readonly property int fontSizeS: 12
    readonly property int fontSizeL: 18

    // ---- color math ----
    // mix(a, b, p): p of a + (1-p) of b, end-4 convention
    function mix(a, b, p) {
        const c1 = Qt.color(a), c2 = Qt.color(b)
        return Qt.rgba(p * c1.r + (1 - p) * c2.r,
                       p * c1.g + (1 - p) * c2.g,
                       p * c1.b + (1 - p) * c2.b,
                       p * c1.a + (1 - p) * c2.a)
    }
    function alpha(c, a) {
        const q = Qt.color(c)
        return Qt.rgba(q.r, q.g, q.b, a)
    }

    // ---- live palette feed ----
    function applyPalette(raw) {
        let j
        try { j = JSON.parse(raw) } catch (e) {
            console.log("[lilypad] palette parse failed: " + e)
            return
        }
        function pick(k, cur) { return (k in j && j[k]) ? j[k] : cur }
        m3background = pick("background", m3background)
        m3onBackground = pick("on_background", m3onBackground)
        m3surfaceDim = pick("surface_dim", m3surfaceDim)
        m3surfaceBright = pick("surface_bright", m3surfaceBright)
        m3surfaceContainerLowest = pick("surface_container_lowest", m3surfaceContainerLowest)
        m3surfaceContainerLow = pick("surface_container_low", m3surfaceContainerLow)
        m3surfaceContainer = pick("surface_container", m3surfaceContainer)
        m3surfaceContainerHigh = pick("surface_container_high", m3surfaceContainerHigh)
        m3surfaceContainerHighest = pick("surface_container_highest", m3surfaceContainerHighest)
        m3onSurface = pick("on_surface", m3onSurface)
        m3onSurfaceVariant = pick("on_surface_variant", m3onSurfaceVariant)
        m3outline = pick("outline", m3outline)
        m3outlineVariant = pick("outline_variant", m3outlineVariant)
        m3primary = pick("primary", m3primary)
        m3onPrimary = pick("on_primary", m3onPrimary)
        m3primaryContainer = pick("primary_container", m3primaryContainer)
        m3onPrimaryContainer = pick("on_primary_container", m3onPrimaryContainer)
        m3inversePrimary = pick("inverse_primary", m3inversePrimary)
        m3secondary = pick("secondary", m3secondary)
        m3onSecondary = pick("on_secondary", m3onSecondary)
        m3secondaryContainer = pick("secondary_container", m3secondaryContainer)
        m3onSecondaryContainer = pick("on_secondary_container", m3onSecondaryContainer)
        m3tertiary = pick("tertiary", m3tertiary)
        m3onTertiary = pick("on_tertiary", m3onTertiary)
        m3tertiaryContainer = pick("tertiary_container", m3tertiaryContainer)
        m3onTertiaryContainer = pick("on_tertiary_container", m3onTertiaryContainer)
        m3error = pick("error", m3error)
        m3onError = pick("on_error", m3onError)
        m3errorContainer = pick("error_container", m3errorContainer)
        m3onErrorContainer = pick("on_error_container", m3onErrorContainer)
        m3inverseSurface = pick("inverse_surface", m3inverseSurface)
        m3inverseOnSurface = pick("inverse_on_surface", m3inverseOnSurface)
        m3shadow = pick("shadow", m3shadow)
        m3scrim = pick("scrim", m3scrim)
        m3sourceColor = pick("source_color", m3sourceColor)
        console.log("[lilypad] palette applied, primary " + m3primary)
    }

    FileView {
        id: paletteFile
        path: Quickshell.env("HOME") + "/.local/state/quickshell/lilypad/colors.json"
        watchChanges: true
        // matugen may still be mid-write when the change event fires; settle first
        onFileChanged: settle.restart()
        onLoaded: root.applyPalette(text())
    }
    Timer {
        id: settle
        interval: 120
        onTriggered: paletteFile.reload()
    }
}
