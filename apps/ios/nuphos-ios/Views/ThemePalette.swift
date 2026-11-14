import Foundation

/// One sRGB colour, `0xRRGGBB`.
///
/// Foundation only, so the contrast tests can measure the same values the app
/// draws without importing SwiftUI.
struct RGBColor: Equatable, Sendable {
    let hex: UInt32

    init(hex: UInt32) {
        self.hex = hex & 0xFFFFFF
    }

    private var components: (red: Double, green: Double, blue: Double) {
        (
            Double((hex >> 16) & 0xFF) / 255,
            Double((hex >> 8) & 0xFF) / 255,
            Double(hex & 0xFF) / 255
        )
    }

    /// This colour at `opacity` over an opaque `background`, as an opaque colour.
    func composited(over background: RGBColor, opacity: Double) -> RGBColor {
        let alpha = min(max(opacity, 0), 1)
        let front = components
        let back = background.components
        func mix(_ front: Double, _ back: Double) -> UInt32 {
            let value = alpha * front + (1 - alpha) * back
            return UInt32((value * 255).rounded())
        }
        return RGBColor(hex: mix(front.red, back.red) << 16 | mix(front.green, back.green) << 8 | mix(front.blue, back.blue))
    }

    /// WCAG 2.1 relative luminance.
    var relativeLuminance: Double {
        func linear(_ value: Double) -> Double {
            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        let rgb = components
        return 0.2126 * linear(rgb.red) + 0.7152 * linear(rgb.green) + 0.0722 * linear(rgb.blue)
    }

    /// WCAG 2.1 contrast ratio, from 1 (identical) to 21 (black on white).
    func contrastRatio(against other: RGBColor) -> Double {
        let a = relativeLuminance
        let b = other.relativeLuminance
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}

/// Light and dark values for one semantic colour.
struct PaletteColor: Equatable, Sendable {
    let light: RGBColor
    let dark: RGBColor

    init(light: UInt32, dark: UInt32) {
        self.light = RGBColor(hex: light)
        self.dark = RGBColor(hex: dark)
    }

    init(light: RGBColor, dark: RGBColor) {
        self.light = light
        self.dark = dark
    }

    func value(for scheme: ThemeScheme) -> RGBColor {
        scheme == .dark ? dark : light
    }

    /// Both schemes composited over one background, keeping the two values distinct.
    func composited(over background: PaletteColor, opacity: Double) -> PaletteColor {
        PaletteColor(
            light: light.composited(over: background.light, opacity: opacity),
            dark: dark.composited(over: background.dark, opacity: opacity)
        )
    }
}

enum ThemeScheme: Equatable, Sendable {
    case light
    case dark
}

/// The raw palette shared by `Theme` (which draws it) and the contrast tests
/// (which measure it), so a change to a theme colour reaches both.
enum ThemePalette {
    static let canvas = PaletteColor(light: 0xF7F7F7, dark: 0x141414)
    static let surface = PaletteColor(light: 0xFFFFFF, dark: 0x202024)
    static let brand = PaletteColor(light: 0x7D36EC, dark: 0x8B4DFF)
    static let heading = PaletteColor(light: 0x18181B, dark: 0xFFFFFF)
    static let body = PaletteColor(light: 0x52525B, dark: 0xA1A1AA)
    static let muted = PaletteColor(light: 0x84848C, dark: 0x71717A)

    /// The empty Bots sentence. `muted` measured below the 4.5:1 body-text
    /// floor, so the designer approved these darker/lighter greys for it:
    /// #5C5C63 light and #A0A0A8 dark.
    static let emptyBotsHint = PaletteColor(light: 0x5C5C63, dark: 0xA0A0A8)

    /// Label and glyph on the brand fill: white in both schemes.
    static let onBrand = PaletteColor(light: 0xFFFFFF, dark: 0xFFFFFF)

    /// The New Bot "not ready" fill: `muted` at 45% over `surface`, resolved to
    /// an opaque colour (#C8C8CB in the light), so contrast never depends on
    /// the row behind the button.
    static let newBotNotReadyFill = muted.composited(over: surface, opacity: 0.45)

    /// Text and glyph on `newBotNotReadyFill`. `body` measures only 4.63:1 in
    /// the light and 3.77:1 in the dark, so the light uses the designer's dark
    /// grey and the dark lifts to a muted light grey (never white).
    static let newBotNotReadyForeground = PaletteColor(light: 0x48484A, dark: 0xD4D4D8)

    /// The Cloud runtime status dot: green when the runtime answers, red when
    /// it does not (and for a disabled runtime, which keeps the offline shape).
    /// Both clear 3:1 on `canvas` and `surface` in each scheme.
    static let dotOnline = PaletteColor(light: 0x1B7F3B, dark: 0x30D158)
    static let dotOffline = PaletteColor(light: 0xFF3B30, dark: 0xFF453A)
}

/// The Cloud runtime status dot's shared state and geometry.
///
/// Foundation only, like `ThemePalette`, so the contrast test can check that
/// the two states differ by shape as well as by colour: both are filled
/// circles, and only the offline state carries one diagonal slash.
enum RuntimeDotState: Equatable, Sendable {
    case online
    case offline

    init(online: Bool) {
        self = online ? .online : .offline
    }

    /// Both states are filled circles.
    var isFilled: Bool { true }

    /// Offline cuts the dot with one slash; online has none.
    var drawsSlash: Bool { self == .offline }

    /// The dot's diameter in points.
    var diameter: Double { 8 }

    /// The slash's thickness in points.
    var slashWidth: Double { 1.5 }

    /// The slash runs diagonally, so the two states also differ in silhouette.
    var slashAngleDegrees: Double { 45 }
}
