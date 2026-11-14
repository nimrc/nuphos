import Foundation

/// Pins the one New Bot entry's contrast in every state and scheme.
///
/// The label is text, so it must clear 4.5:1 (WCAG 2.2 AA 1.4.3 for normal
/// text; 3:1 would apply only to large text, so 4.5:1 is the stricter rule and
/// the one used here). The plus glyph and the spinner are non-text graphics,
/// so they must clear 3:1 (1.4.11). Every colour comes from `ThemePalette` via
/// `NewBotButtonAppearance`; none is copied from the design note.
///
/// The single entry draws `fill` as a rounded rectangle behind
/// `label`/`glyph`. It is full width and pinned above the scrolling List,
/// including when the list is empty. The navigation-bar plus was removed; the
/// source checks below keep it out and keep the three states on this one
/// entry.
enum NewBotButtonContrastTests {
    private static let textFloor = 4.5
    private static let graphicFloor = 3.0

    static func run() {
        statesResolveDistinctly()
        notReadyIsDrawnUndimmed()
        oneEntryExplainsAllThreeStates()
        for scheme in [ThemeScheme.light, .dark] {
            print("New Bot contrast — \(scheme == .dark ? "dark" : "light")")
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

    /// The one entry reads the shared appearance, uses its colours and flags,
    /// is full width and pinned above the List including when empty, and
    /// explains all three states. The navigation-bar plus must stay deleted
    /// rather than hidden: nothing focusable is left on the bar.
    private static func oneEntryExplainsAllThreeStates() {
        let source = agentPageSource()

        let shared = section("private var newBotAppearance", in: source)
        precondition(shared.contains(": NewBotButtonAppearance"), "newBotAppearance is not typed as NewBotButtonAppearance")
        precondition(shared.contains(".resolve(newBotState, scheme:"), "newBotAppearance no longer resolves from the state and scheme")
        // One resolution site: the entry may not resolve (or hardcode) its own.
        precondition(occurrences(of: ".resolve(newBotState", in: source) == 1,
                     "AgentPage must resolve the appearance once, in newBotAppearance")
        precondition(occurrences(of: "NewBotButtonAppearance.resolve(", in: source) == 0,
                     "The entry resolved its own appearance instead of reading newBotAppearance")

        // The bar entry is deleted, not hidden.
        for removed in ["newBotBarButton", "newBotToolbarItem", "BareNavigationSpinner", "barGlyph", "barSpinner"] {
            precondition(!source.contains(removed), "The removed navigation-bar plus is still present: \(removed)")
        }

        let row = section("private var newBotRow", in: source)
        precondition(!row.isEmpty, "Could not find the New Bot row in AgentPage")
        for token in ["newBotAppearance.acceptsTaps", "newBotAppearance.readsAsDisabled",
                      "newBotAccessibilityHint", "newBotAccessibilityValue",
                      ".frame(maxWidth: .infinity)", ".disabled(newBotAppearance.readsAsDisabled)",
                      ".accessibilityLabel(\"New Bot\")"] {
            precondition(row.contains(token), "The New Bot row does not read \(token) from the shared appearance")
        }
        for token in ["newBotAppearance.fill.color", "newBotAppearance.label.color",
                      "newBotAppearance.glyph.color", "newBotAppearance.spinner"] {
            precondition(row.contains(token), "The row does not read \(token) from the shared appearance")
        }

        // All three states are explained on this one entry.
        let hint = section("private var newBotAccessibilityHint", in: source)
        precondition(hint.contains("Creating the Bot"), "Creating is no longer explained on the row")
        precondition(hint.contains("Loading runtimes…"), "Not ready is no longer explained on the row")
        precondition(hint.contains("Creates a Bot with its own chat"), "Ready is no longer explained on the row")
        precondition(section("private var newBotAccessibilityValue", in: source).contains("In progress"),
                     "Creating no longer announces progress")

        // Full width and pinned above the List, with no separate empty-state
        // button and no list-row insets (it no longer scrolls with the rows).
        precondition(row.contains(".padding(.horizontal, 20)") && row.contains(".padding(.vertical, 8)"),
                     "The pinned entry lost its 20 pt side insets")
        precondition(!row.contains(".listRowInsets") && !row.contains(".listRowBackground"),
                     "The pinned entry is still styled as a scrolling list row")
        let content = section("private var content", in: source)
        guard let pinned = content.range(of: "newBotRow")?.lowerBound,
              let list = content.range(of: "                list")?.lowerBound else {
            preconditionFailure("Could not find the pinned entry above the List")
        }
        precondition(pinned < list, "The New Bot entry is no longer pinned above the List")
        precondition(!section("private var list", in: source).contains("newBotRow"),
                     "The New Bot entry is back inside the scrolling List")
        precondition(source.contains("if store.botsList.isEmpty {\n                Text(\"Give each Bot its own chat\")"),
                     "The empty state became a second button instead of the same row's subtitle")
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
