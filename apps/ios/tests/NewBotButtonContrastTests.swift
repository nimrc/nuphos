import Foundation

/// Pins the New Bot entry's contrast in every state and scheme.
///
/// The label is text, so it must clear 4.5:1 (WCAG 2.2 AA 1.4.3 for normal
/// text; 3:1 would apply only to large text, so 4.5:1 is the stricter rule and
/// the one used here). The plus glyph and the spinner are non-text graphics,
/// so they must clear 3:1 (1.4.11). Every colour comes from `ThemePalette` via
/// `NewBotButtonAppearance`; none is copied from the design note.
enum NewBotButtonContrastTests {
    private static let textFloor = 4.5
    private static let graphicFloor = 3.0

    static func run() {
        statesResolveDistinctly()
        for scheme in [ThemeScheme.light, .dark] {
            print("New Bot contrast — \(scheme == .dark ? "dark" : "light")")
            for state in [NewBotButtonState.ready, .creating, .notReady] {
                let appearance = NewBotButtonAppearance.resolve(state, scheme: scheme)
                let label = appearance.label.contrastRatio(against: appearance.fill)
                let glyph = appearance.glyph.contrastRatio(against: appearance.fill)
                print(String(
                    format: "  %-8@ fill #%06X  label #%06X %.2f:1 (text, floor %.1f)  plus #%06X %.2f:1 (graphic, floor %.1f)",
                    stateName(state) as NSString,
                    appearance.fill.hex,
                    appearance.label.hex, label, textFloor,
                    appearance.glyph.hex, glyph, graphicFloor
                ))
                precondition(label >= textFloor, "\(stateName(state)) label is \(label):1 in \(scheme); text needs \(textFloor):1")
                precondition(glyph >= graphicFloor, "\(stateName(state)) plus glyph is \(glyph):1 in \(scheme); a graphic needs \(graphicFloor):1")
                if let spinner = appearance.spinner {
                    let ratio = spinner.contrastRatio(against: appearance.fill)
                    print(String(
                        format: "           spinner #%06X %.2f:1 (graphic, floor %.1f)",
                        spinner.hex, ratio, graphicFloor
                    ))
                    precondition(ratio >= graphicFloor, "\(stateName(state)) spinner is \(ratio):1 in \(scheme); a graphic needs \(graphicFloor):1")
                }
            }
        }
        print("New Bot contrast passed")
    }

    private static func statesResolveDistinctly() {
        precondition(NewBotButtonState.resolve(creating: false, runtimesLoaded: true) == .ready)
        precondition(NewBotButtonState.resolve(creating: false, runtimesLoaded: false) == .notReady)
        // A running creation wins over an unloaded runtime list: it is still creating.
        precondition(NewBotButtonState.resolve(creating: true, runtimesLoaded: false) == .creating)

        for scheme in [ThemeScheme.light, .dark] {
            let ready = NewBotButtonAppearance.resolve(.ready, scheme: scheme)
            let creating = NewBotButtonAppearance.resolve(.creating, scheme: scheme)
            let notReady = NewBotButtonAppearance.resolve(.notReady, scheme: scheme)

            // Creating keeps the brand fill and white label/spinner, and refuses
            // taps without reading as disabled.
            precondition(creating.fill == ThemePalette.brand.value(for: scheme))
            precondition(creating.label == ThemePalette.onBrand.value(for: scheme))
            precondition(creating.spinner == ThemePalette.onBrand.value(for: scheme))
            precondition(!creating.acceptsTaps && !creating.readsAsDisabled && creating.announcesProgress)
            precondition(creating.fill == ready.fill, "creating must not grey the button out")

            // Not ready is the only light fill, and never white text.
            precondition(notReady.fill == ThemePalette.newBotNotReadyFill.value(for: scheme))
            precondition(notReady.label == ThemePalette.newBotNotReadyForeground.value(for: scheme))
            precondition(notReady.label != ThemePalette.onBrand.value(for: scheme), "not-ready text must not be white")
            precondition(notReady.fill != ThemePalette.brand.value(for: scheme))
            precondition(!notReady.acceptsTaps && notReady.readsAsDisabled && !notReady.announcesProgress)

            precondition(ready.acceptsTaps && !ready.readsAsDisabled && !ready.announcesProgress)
            precondition(ready.spinner == nil && notReady.spinner == nil)

            // The defect itself: white on the old 45% muted fill is far below
            // the text floor in the light, and the new fill fixes it.
            let oldFill = ThemePalette.muted.composited(over: ThemePalette.surface, opacity: 0.45).value(for: scheme)
            let oldText = ThemePalette.onBrand.value(for: scheme).contrastRatio(against: oldFill)
            if scheme == .light {
                precondition(oldText < textFloor, "The old white-on-muted fill unexpectedly passed")
            }
        }
    }

    private static func stateName(_ state: NewBotButtonState) -> String {
        switch state {
        case .ready: return "ready"
        case .creating: return "creating"
        case .notReady: return "notReady"
        }
    }
}
