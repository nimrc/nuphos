import Foundation

/// The New Bot entry has three states. "Creating" (a Bot's first chat is being
/// made) is not the disabled state: it keeps the brand fill and refuses taps.
/// "Not ready" (usually the runtime list has not loaded) is the only state
/// with the lighter fill.
enum NewBotButtonState: Equatable, Sendable {
    case ready
    case creating
    case notReady

    static func resolve(creating: Bool, runtimesLoaded: Bool) -> NewBotButtonState {
        if creating { return .creating }
        return runtimesLoaded ? .ready : .notReady
    }
}

/// The colours and behaviour both New Bot entries draw for one state.
///
/// Foundation only: the contrast test resolves the same appearance the view
/// draws, from the same `ThemePalette` values.
struct NewBotButtonAppearance: Equatable, Sendable {
    let state: NewBotButtonState
    /// The button's own opaque background.
    let fill: RGBColor
    /// The "New Bot" label.
    let label: RGBColor
    /// The plus glyph, when there is one, on the button's own fill.
    let glyph: RGBColor
    /// The plus glyph as drawn in the navigation bar, where it sits straight
    /// on the bar instead of on `fill`: a bare glyph is what a navigation bar
    /// takes, not a filled disc.
    let barGlyph: RGBColor
    /// The in-flight spinner on the button's own fill, only in the creating state.
    let spinner: RGBColor?
    /// The in-flight spinner as drawn bare in the navigation bar, only in the
    /// creating state. Progress must stay visible without a disc.
    let barSpinner: RGBColor?
    /// Whether a tap starts a creation.
    let acceptsTaps: Bool
    /// Whether assistive technology should announce the button as disabled.
    /// Creating keeps the brand fill, so it deliberately does not read disabled.
    let readsAsDisabled: Bool
    /// Whether VoiceOver should say a creation is running.
    let announcesProgress: Bool

    static func resolve(_ state: NewBotButtonState, scheme: ThemeScheme) -> NewBotButtonAppearance {
        switch state {
        case .ready:
            return NewBotButtonAppearance(
                state: state,
                fill: ThemePalette.brand.value(for: scheme),
                label: ThemePalette.onBrand.value(for: scheme),
                glyph: ThemePalette.onBrand.value(for: scheme),
                barGlyph: ThemePalette.brand.value(for: scheme),
                spinner: nil,
                barSpinner: nil,
                acceptsTaps: true,
                readsAsDisabled: false,
                announcesProgress: false
            )
        case .creating:
            return NewBotButtonAppearance(
                state: state,
                fill: ThemePalette.brand.value(for: scheme),
                label: ThemePalette.onBrand.value(for: scheme),
                glyph: ThemePalette.onBrand.value(for: scheme),
                barGlyph: ThemePalette.brand.value(for: scheme),
                spinner: ThemePalette.onBrand.value(for: scheme),
                barSpinner: ThemePalette.brand.value(for: scheme),
                acceptsTaps: false,
                readsAsDisabled: false,
                announcesProgress: true
            )
        case .notReady:
            return NewBotButtonAppearance(
                state: state,
                fill: ThemePalette.newBotNotReadyFill.value(for: scheme),
                label: ThemePalette.newBotNotReadyForeground.value(for: scheme),
                glyph: ThemePalette.newBotNotReadyForeground.value(for: scheme),
                barGlyph: ThemePalette.muted.value(for: scheme),
                spinner: nil,
                barSpinner: nil,
                acceptsTaps: false,
                readsAsDisabled: true,
                announcesProgress: false
            )
        }
    }
}
