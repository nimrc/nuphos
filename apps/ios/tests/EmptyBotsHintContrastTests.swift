import Foundation

/// Measures the empty Bots sentence together with the top-bar New Bot plus in
/// both schemes.
///
/// Every colour is resolved from the production palette the view draws with:
/// `ThemePalette.emptyBotsHint` on `ThemePalette.canvas` for the sentence, and
/// `NewBotButtonAppearance.resolve` for the plus and spinner on the bar. None
/// is copied from the design note.
///
/// Body text needs 4.5:1 (WCAG 2.2 AA 1.4.3); a glyph or spinner needs 3:1
/// (1.4.11).
enum EmptyBotsHintContrastTests {
    private static let textFloor = 4.5
    private static let graphicFloor = 3.0
    private static let hintEnglish = "No Bots yet. Tap + in the top right to create one."

    static func run() {
        hintReadsTheApprovedThemeSlot()
        for scheme in [ThemeScheme.light, .dark] {
            // The Bots list draws the sentence straight on the page canvas;
            // the navigation bar uses the same canvas behind the plus.
            let page = ThemePalette.canvas.value(for: scheme)
            let hint = ThemePalette.emptyBotsHint.value(for: scheme)
            let hintRatio = hint.contrastRatio(against: page)

            print("Empty Bots hint and New Bot plus — \(scheme == .dark ? "dark" : "light")")
            print(String(
                format: "  empty hint #%06X on canvas #%06X %.2f:1 (text, floor %.1f)",
                hint.hex, page.hex, hintRatio, textFloor
            ))
            precondition(hintRatio >= textFloor, "The empty Bots hint is \(hintRatio):1 on the canvas in \(scheme); body text needs \(textFloor):1")

            for state in [NewBotButtonState.ready, .creating, .notReady] {
                let appearance = NewBotButtonAppearance.resolve(state, scheme: scheme)
                let plusRatio = appearance.barGlyph.contrastRatio(against: page)
                print(String(
                    format: "  toolbar plus %-8@ #%06X on bar #%06X %.2f:1 (glyph, floor %.1f)",
                    stateName(state) as NSString,
                    appearance.barGlyph.hex, page.hex, plusRatio, graphicFloor
                ))
                precondition(plusRatio >= graphicFloor, "\(stateName(state)) bare navigation plus is \(plusRatio):1 on the bar in \(scheme); a glyph needs \(graphicFloor):1")

                if let spinner = appearance.barSpinner {
                    let spinnerRatio = spinner.contrastRatio(against: page)
                    print(String(
                        format: "  toolbar spinner #%06X on bar #%06X %.2f:1 (glyph, floor %.1f)",
                        spinner.hex, page.hex, spinnerRatio, graphicFloor
                    ))
                    precondition(spinnerRatio >= graphicFloor, "\(stateName(state)) bare navigation spinner is \(spinnerRatio):1 on the bar in \(scheme); a glyph needs \(graphicFloor):1")
                }
            }
        }
        ringContrastMatchesTheApprovedBrand()
        print("Empty Bots hint and New Bot plus contrast passed")
    }

    /// The pinned row's current-chat ring. The designer confirmed 4.05:1 in
    /// the dark scheme is the approved value, not the 4.6 once printed.
    private static func ringContrastMatchesTheApprovedBrand() {
        for (scheme, expected) in [(ThemeScheme.light, 5.43), (.dark, 4.05)] {
            let page = ThemePalette.canvas.value(for: scheme)
            let ring = ThemePalette.brand.value(for: scheme)
            let ratio = ring.contrastRatio(against: page)
            print(String(
                format: "  pinned ring #%06X on canvas #%06X %.2f:1 (approved %.2f)",
                ring.hex, page.hex, ratio, expected
            ))
            precondition(abs(ratio - expected) < 0.02,
                         "the pinned ring is \(ratio):1 in \(scheme); the approved value is \(expected):1")
        }
    }

    /// The sentence takes its colour from the shared palette slot, not from
    /// `Theme.muted` and not from a literal.
    private static func hintReadsTheApprovedThemeSlot() {
        let source = (try? String(contentsOfFile: "nuphos-ios/Views/Home/AgentPage.swift", encoding: .utf8)) ?? ""
        precondition(source.contains("Text(\"\(hintEnglish)\")"), "The empty Bots sentence lost its exact copy")
        precondition(source.contains(".foregroundStyle(Theme.emptyBotsHint)"),
                     "The empty Bots sentence does not use Theme.emptyBotsHint")
        precondition(!source.contains(".foregroundStyle(Theme.muted)\n                            .multilineTextAlignment(.center)"),
                     "The empty Bots sentence still uses the muted grey")
    }

    private static func stateName(_ state: NewBotButtonState) -> String {
        switch state {
        case .ready: return "ready"
        case .creating: return "creating"
        case .notReady: return "notReady"
        }
    }
}
