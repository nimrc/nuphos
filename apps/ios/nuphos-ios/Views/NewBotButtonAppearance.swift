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
    /// The plus glyph, when there is one.
    let glyph: RGBColor
    /// The in-flight spinner, only in the creating state.
    let spinner: RGBColor?
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
                spinner: nil,
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
                spinner: ThemePalette.onBrand.value(for: scheme),
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
                spinner: nil,
                acceptsTaps: false,
                readsAsDisabled: true,
                announcesProgress: false
            )
        }
    }
}
