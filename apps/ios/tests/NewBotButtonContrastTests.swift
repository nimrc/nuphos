import Foundation

/// Pins the New Bot entry's contrast in every state and scheme, for both
/// entry points.
///
/// The label is text, so it must clear 4.5:1 (WCAG 2.2 AA 1.4.3 for normal
/// text; 3:1 would apply only to large text, so 4.5:1 is the stricter rule and
/// the one used here). The plus glyph and the spinner are non-text graphics,
/// so they must clear 3:1 (1.4.11). Every colour comes from `ThemePalette` via
/// `NewBotButtonAppearance`; none is copied from the design note.
///
/// The list row draws `fill` as a rounded rectangle behind `label`/`glyph`.
/// The navigation-bar entry draws no fill at all: a navigation bar takes a
/// bare `barGlyph`/`barSpinner` straight on the bar, so that glyph is measured
/// against the bar background. Both entries read one `NewBotButtonAppearance`,
/// and the source check below stops them gaining separate state or colours.
enum NewBotButtonContrastTests {
    private static let textFloor = 4.5
    private static let graphicFloor = 3.0

    static func run() {
        statesResolveDistinctly()
        notReadyIsDrawnUndimmed()
        bothEntriesUseTheSameAppearance()
        for scheme in [ThemeScheme.light, .dark] {
            print("New Bot contrast — \(scheme == .dark ? "dark" : "light")")
            // The bar's own background: sampled from the running app's
            // navigation bar in both schemes (#F7F7F7 / #141414).
            let bar = ThemePalette.canvas.value(for: scheme)
            for state in [NewBotButtonState.ready, .creating, .notReady] {
                let appearance = NewBotButtonAppearance.resolve(state, scheme: scheme)

                // List row: label and plus on the fill.
                let label = appearance.label.contrastRatio(against: appearance.fill)
                let rowGlyph = appearance.glyph.contrastRatio(against: appearance.fill)
                print(String(
                    format: "  row      %-8@ fill #%06X  label #%06X %.2f:1 (text, floor %.1f)  plus #%06X %.2f:1 (graphic, floor %.1f)",
                    stateName(state) as NSString,
                    appearance.fill.hex,
                    appearance.label.hex, label, textFloor,
                    appearance.glyph.hex, rowGlyph, graphicFloor
                ))
                precondition(label >= textFloor, "\(stateName(state)) label is \(label):1 in \(scheme); text needs \(textFloor):1")
                precondition(rowGlyph >= graphicFloor, "\(stateName(state)) row plus glyph is \(rowGlyph):1 in \(scheme); a graphic needs \(graphicFloor):1")

                // Navigation bar: the bare glyph sits straight on the bar —
                // no disc and no row fill — so measure it against the bar.
                let barGlyph = appearance.barGlyph.contrastRatio(against: bar)
                print(String(
                    format: "  navplus  %-8@ bare+#%06X on bar #%06X %.2f:1 (glyph, floor %.1f)",
                    stateName(state) as NSString,
                    appearance.barGlyph.hex, bar.hex, barGlyph, graphicFloor
                ))
                precondition(barGlyph >= graphicFloor, "\(stateName(state)) bare navigation plus is \(barGlyph):1 on the bar in \(scheme); a glyph needs \(graphicFloor):1")

                if let spinner = appearance.barSpinner {
                    let barSpinner = spinner.contrastRatio(against: bar)
                    print(String(
                        format: "           bare spinner #%06X on bar #%06X %.2f:1 (glyph, floor %.1f)",
                        spinner.hex, bar.hex, barSpinner, graphicFloor
                    ))
                    precondition(barSpinner >= graphicFloor, "\(stateName(state)) bare navigation spinner is \(barSpinner):1 on the bar in \(scheme); a glyph needs \(graphicFloor):1")
                }

                if let spinner = appearance.spinner {
                    let spinnerOnFill = spinner.contrastRatio(against: appearance.fill)
                    print(String(
                        format: "           row spinner #%06X on fill #%06X %.2f:1 (glyph, floor %.1f)",
                        spinner.hex, appearance.fill.hex, spinnerOnFill, graphicFloor
                    ))
                    precondition(spinnerOnFill >= graphicFloor, "\(stateName(state)) row spinner is \(spinnerOnFill):1 in \(scheme); a glyph needs \(graphicFloor):1")
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

            // The navigation bar draws the same states as bare colours on the
            // bar: brand for ready and creating, muted for not ready, and the
            // bare spinner while creating. White is never used on the bar.
            precondition(ready.barGlyph == ThemePalette.brand.value(for: scheme))
            precondition(creating.barGlyph == ThemePalette.brand.value(for: scheme))
            precondition(notReady.barGlyph == ThemePalette.muted.value(for: scheme))
            precondition(ready.barSpinner == nil && notReady.barSpinner == nil)
            precondition(creating.barSpinner == ThemePalette.brand.value(for: scheme))
            precondition(ready.barGlyph != ThemePalette.onBrand.value(for: scheme), "white cannot sit on the navigation bar")

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

    /// The not-ready control is disabled for VoiceOver. SwiftUI's `.plain`
    /// button style dims a disabled label toward the row: rendered #48484A on
    /// #C8C8CB fell to about #939395 on #DFDFE1, 2.30:1. `AgentPage` draws it
    /// with `NewBotButtonStyle`, which keeps the colours the test measures.
    private static func notReadyIsDrawnUndimmed() {
        let source = agentPageSource()
        precondition(source.contains(".buttonStyle(NewBotButtonStyle())"), "The New Bot row lost its non-dimming button style")
    }

    /// Both the list row and the navigation-bar plus read the one appearance
    /// value annotated as `NewBotButtonAppearance`, and use its colours and
    /// flags. The bar must not name a colour of its own (the build-8 defect
    /// was a hardcoded `Theme.brand` plus) and must not paint a disc (build
    /// 9's defect).
    private static func bothEntriesUseTheSameAppearance() {
        let source = agentPageSource()

        let shared = section("private var newBotAppearance", in: source)
        precondition(shared.contains(": NewBotButtonAppearance"), "newBotAppearance is not typed as NewBotButtonAppearance")
        precondition(shared.contains(".resolve(newBotState, scheme:"), "newBotAppearance no longer resolves from the state and scheme")
        // One resolution site: neither entry may resolve (or hardcode) its own.
        precondition(occurrences(of: ".resolve(newBotState", in: source) == 1,
                     "AgentPage must resolve the appearance once, in newBotAppearance")
        precondition(occurrences(of: "NewBotButtonAppearance.resolve(", in: source) == 0,
                     "An entry resolved its own appearance instead of reading newBotAppearance")

        let row = section("private var newBotRow", in: source)
        let bar = section("private var newBotBarButton", in: source)
        precondition(!row.isEmpty && !bar.isEmpty, "Could not find both New Bot entry points in AgentPage")

        for (name, entry) in [("row", row), ("navigation bar", bar)] {
            for token in ["newBotAppearance.acceptsTaps", "newBotAppearance.readsAsDisabled",
                          "newBotAccessibilityHint", "newBotAccessibilityValue"] {
                precondition(entry.contains(token), "The \(name) entry does not read \(token) from the shared appearance")
            }
            precondition(entry.contains(".disabled(newBotAppearance.readsAsDisabled)"),
                         "The \(name) entry does not disable itself from the shared appearance")
        }
        for token in ["newBotAppearance.fill.color", "newBotAppearance.label.color",
                      "newBotAppearance.glyph.color", "newBotAppearance.spinner"] {
            precondition(row.contains(token), "The row does not read \(token) from the shared appearance")
        }
        for token in ["newBotAppearance.barGlyph.color", "newBotAppearance.barSpinner"] {
            precondition(bar.contains(token), "The navigation bar does not read \(token) from the shared appearance")
        }

        // A navigation bar takes a bare glyph: no disc, no row fill, and no
        // colour of its own.
        precondition(!bar.contains("Theme."), "The navigation bar plus hardcodes a Theme colour again")
        precondition(!bar.contains("Color(") && !bar.contains("Color."), "The navigation bar plus builds a colour of its own")
        precondition(!bar.contains("Circle("), "The navigation bar plus draws a disc again")
        precondition(!bar.contains(".fill("), "The navigation bar plus paints a fill again")
        precondition(!bar.contains(".background("), "The navigation bar plus draws a background again")
        precondition(!bar.contains("newBotAppearance.fill"), "The bare navigation plus must not use the row fill")
        precondition(!bar.contains("newBotAppearance.glyph"), "The row's on-fill glyph colour is white and cannot sit on the bar")
        precondition(bar.contains("Image(systemName: \"plus\")"), "The navigation bar lost its plus glyph")
        precondition(bar.contains("BareNavigationSpinner(color: spinner.color)"), "The navigation bar plus does not draw the full-opacity bare spinner from the shared appearance")
        precondition(!bar.contains("ProgressView()"), "The navigation bar spinner faded its arc below the glyph floor again")

        // Accessibility follows the appearance, not a second state read.
        precondition(!source.contains("newBotState == .creating ? Text("), "An entry describes creating from the raw state instead of the appearance")
        precondition(source.contains("announcesProgress ? Text(\"In progress\")"), "Creating no longer announces progress")
    }

    private static func agentPageSource() -> String {
        (try? String(contentsOfFile: "nuphos-ios/Views/Home/AgentPage.swift", encoding: .utf8)) ?? ""
    }

    /// The text from `marker` to the next member declaration at the same
    /// indentation, which is one computed view property.
    private static func section(_ marker: String, in source: String) -> String {
        guard let start = source.range(of: marker) else { return "" }
        let rest = source[start.lowerBound...]
        if let end = rest.range(of: "\n    private var ", range: rest.index(rest.startIndex, offsetBy: marker.count)..<rest.endIndex)
            ?? rest.range(of: "\n    private func ", range: rest.index(rest.startIndex, offsetBy: marker.count)..<rest.endIndex) {
            return String(rest[..<end.lowerBound])
        }
        return String(rest)
    }

    private static func occurrences(of needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
    }

    private static func stateName(_ state: NewBotButtonState) -> String {
        switch state {
        case .ready: return "ready"
        case .creating: return "creating"
        case .notReady: return "notReady"
        }
    }
}
