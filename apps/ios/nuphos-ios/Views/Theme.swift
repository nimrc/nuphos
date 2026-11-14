import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Palette that follows the system appearance. Every color here has a light
/// and a dark value; views never force a color scheme.
enum Theme {
    /// Page background: #F7F7F7 light, #141414 dark.
    static let canvas = adaptive(ThemePalette.canvas)
    /// Grouped rows / cards on top of the canvas.
    static let surface = adaptive(ThemePalette.surface)
    /// The chat transcript reads like a page: #FFFFFF light, #141414 dark.
    static let chatCanvas = adaptive(ThemePalette.chatCanvas)
    /// Chips and cards inside the transcript, which `surface` cannot be
    /// because it matches the transcript's own light-mode background.
    static let chatSurface = adaptive(ThemePalette.chatSurface)
    /// The user's own chat bubble: a shade off the canvas in either scheme.
    static let bubble = adaptive(ThemePalette.bubble)
    /// Brand violet (`--landing-brand`), brighter in the dark so it keeps contrast.
    static let brand = adaptive(ThemePalette.brand)
    /// Brand used as text/tint on the surfaces.
    static let brandText = adaptive(ThemePalette.brandText)
    /// Unread reply dot — desktop's `bg-zViolet-500`, lifted in the dark
    /// the way `brand` is so it keeps contrast against #141414.
    static let unread = adaptive(light: 0x6300FF, dark: 0x8B4DFF)
    /// Avatar fallback gradient — zViolet-500 → zViolet-700.
    static let violet500 = Color(hex: 0x6300FF)
    static let violet700 = Color(hex: 0x3E14A2)

    static let heading = adaptive(ThemePalette.heading)
    static let body = adaptive(ThemePalette.body)
    static let muted = adaptive(ThemePalette.muted)
    /// The empty Bots sentence: the designer-approved body-text grey.
    static let emptyBotsHint = adaptive(ThemePalette.emptyBotsHint)
    /// Desktop `--color-warning`, darkened in light mode for contrast.
    static let warning = adaptive(ThemePalette.warning)
    /// Text for a spent limit or a refused action, measured in both schemes.
    static let danger = adaptive(ThemePalette.danger)
    static let hairline = adaptive(light: 0x18181B, dark: 0xFFFFFF, lightAlpha: 0.08, darkAlpha: 0.10)

    /// Label and glyph on the brand fill.
    static let onBrand = adaptive(ThemePalette.onBrand)
    /// The primary action's disabled fill and label, measured in both schemes.
    static let primaryButtonDisabledFill = adaptive(ThemePalette.primaryButtonDisabledFill)
    static let primaryButtonDisabledForeground = adaptive(ThemePalette.primaryButtonDisabledForeground)
    /// The composer bar's opaque fill. It replaces the glass on the composer
    /// so a pure-white attachment cannot lift the Attach/Mic backdrop.
    static let composerBarFill = adaptive(ThemePalette.composerBarFill)
    /// The Bots list's thread-count capsule, opaque so its ratio is fixed.
    static let threadCapsuleFill = adaptive(ThemePalette.threadCapsuleFill)
    /// The disabled send key: the light disc keeps its 60% `muted` exactly;
    /// the dark disc is 85%, matching the #4D4C51 pixel sampled from the dark
    /// glass. It is an inactive control, so WCAG 1.4.3/1.4.11 exempt it.
    static let composerSendDisabledFill = adaptive(
        light: ThemePalette.muted.light.hex, dark: ThemePalette.muted.dark.hex,
        lightAlpha: 0.6, darkAlpha: 0.85
    )
    /// The New Bot "not ready" fill: `muted` at 45% over `surface`, opaque.
    static let newBotNotReadyFill = adaptive(ThemePalette.newBotNotReadyFill)
    /// Label and plus glyph on `newBotNotReadyFill`.
    static let newBotNotReadyForeground = adaptive(ThemePalette.newBotNotReadyForeground)

    /// The Cloud runtime status dot: green online, red offline (also the
    /// disabled runtime's shape). Never `Color.green`/`Color.red`, so the
    /// contrast tests measure the palette the view actually draws.
    static let dotOnline = adaptive(ThemePalette.dotOnline)
    static let dotOffline = adaptive(ThemePalette.dotOffline)

    private static func adaptive(_ color: PaletteColor) -> Color {
        adaptive(light: color.light.hex, dark: color.dark.hex)
    }

    private static func adaptive(
        light: UInt32, dark: UInt32,
        lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1
    ) -> Color {
        #if canImport(UIKit)
        return Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark, alpha: darkAlpha)
                : UIColor(hex: light, alpha: lightAlpha)
        })
        #elseif canImport(AppKit)
        return Color(NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? NSColor(hex: dark, alpha: darkAlpha) : NSColor(hex: light, alpha: lightAlpha)
        })
        #else
        return Color(hex: light)
        #endif
    }
}

extension View {
    /// The filled call-to-action. The app tints with `Theme.heading`, which
    /// is white in the dark — the color `.borderedProminent` draws its label
    /// in — so the fill takes the brand instead.
    func prominentButton() -> some View {
        buttonStyle(.borderedProminent).tint(Theme.brand)
    }

    /// A destructive secondary action. `.bordered` tints its material with the
    /// tint, and a danger-tinted fill drops `danger` to 3.87:1 in the dark;
    /// this keeps the measured opaque surface fill and draws the danger in the
    /// label and a hairline instead (5.76:1 in both schemes).
    func dangerBorderedButton() -> some View {
        buttonStyle(Theme.DangerBorderedButtonStyle())
    }

    /// The composer's surface. The dark composer is opaque canvas so a
    /// bright attachment cannot lift Attach/Mic; the light composer keeps the
    /// glass it had, because its body colour clears the floor on white.
    @ViewBuilder
    func composerSurface(isDark: Bool, in shape: some Shape) -> some View {
        if isDark {
            background(Theme.composerBarFill, in: shape)
        } else {
            glass(interactive: true, in: shape)
        }
    }

    /// Liquid Glass on iOS 26 and later; a material in the same shape before.
    @ViewBuilder
    func glass(interactive: Bool = false, in shape: some Shape) -> some View {
        if #available(iOS 26, *) {
            glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        } else {
            background(.regularMaterial, in: shape)
        }
    }

    /// The glass call-to-action on iOS 26; the bordered one before it.
    /// Brand-tinted, so a primary action reads as the same action as
    /// `prominentButton()` rather than taking the white/black `heading` tint.
    @ViewBuilder
    func glassProminentButton() -> some View {
        if #available(iOS 26, *) {
            buttonStyle(.glassProminent).tint(Theme.brand)
        } else {
            buttonStyle(.borderedProminent).tint(Theme.brand)
        }
    }
}

extension Theme {
    /// The secondary destructive key, used where a red action must sit beside
    /// a primary one without taking the primary's fill.
    fileprivate struct DangerBorderedButtonStyle: ButtonStyle {
        @Environment(\.isEnabled) private var isEnabled

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .foregroundStyle(isEnabled ? Theme.danger : Theme.body)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Theme.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.danger.opacity(0.35), lineWidth: 1))
                .opacity(configuration.isPressed ? 0.8 : 1)
        }
    }
}

extension Theme {
    /// Chat typography. Semantic text styles, so the whole scale follows
    /// Dynamic Type; sizes in the comments are the default (Large) ones.
    enum Text {
        /// Message prose — assistant answers and user bubbles. 17pt.
        static let body = Font.body
        /// Supporting prose: thinking, plan steps, tool titles. 15pt.
        static let secondary = Font.subheadline
        /// Activity and status lines. 13pt.
        static let label = Font.footnote
        /// Badges, timestamps and counters. 12pt.
        static let caption = Font.caption
        /// Chevrons and other glyphs set beside caption text. 11pt.
        static let micro = Font.caption2

        static func mono(_ style: Font.TextStyle) -> Font { .system(style, design: .monospaced) }

        /// Extra leading under each line of prose. CJK sets tighter than
        /// Latin at the same size and needs the room; it matches what the
        /// Markdown renderer puts between its own lines.
        static let leading: CGFloat = 4

        #if canImport(UIKit)
        /// The Markdown renderer is themed with `UIFont`s; these resolve the
        /// same styles at the reader's current text size.
        static func uiFont(_ style: UIFont.TextStyle, weight: UIFont.Weight = .regular) -> UIFont {
            let scaled = UIFont.preferredFont(forTextStyle: style)
            guard weight != .regular else { return scaled }
            return .systemFont(ofSize: scaled.pointSize, weight: weight)
        }

        static func italicUIFont(_ style: UIFont.TextStyle) -> UIFont {
            let scaled = UIFont.preferredFont(forTextStyle: style)
            guard let descriptor = scaled.fontDescriptor.withSymbolicTraits(.traitItalic) else { return scaled }
            return UIFont(descriptor: descriptor, size: scaled.pointSize)
        }

        static func monoUIFont(_ style: UIFont.TextStyle) -> UIFont {
            .monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: style).pointSize, weight: .regular)
        }
        #endif
    }
}

extension RGBColor {
    /// The SwiftUI colour for an appearance resolved by `NewBotButtonAppearance`.
    var color: Color { Color(hex: hex) }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

#if canImport(UIKit)
private extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}
#elseif canImport(AppKit)
private extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}
#endif

extension View {
    /// Centers the content in a column no wider than comfortable reading,
    /// for wide windows. Narrower windows are unaffected.
    func readableWidth() -> some View {
        frame(maxWidth: 720).frame(maxWidth: .infinity)
    }
}
