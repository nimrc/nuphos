import Foundation

/// Pins the top-bar New Bot plus in every state and scheme, and the empty
/// Bots sentence as static, localized copy.
///
/// The plus glyph and the spinner are non-text graphics, so they must clear
/// 3:1 (WCAG 2.2 AA 1.4.11). Every colour comes from `ThemePalette` via
/// `NewBotButtonAppearance`; none is copied from the design note.
///
/// The plus is the only creation entry: there is no list row, no pinned row,
/// and no full-width "New Bot" label, empty or not. The empty sentence is a
/// plain `Text` in the Bots section, never a button.
enum NewBotButtonContrastTests {
    private static let graphicFloor = 3.0
    private static let emptyBotsEnglish = "No Bots yet. Tap + in the top right to create one."
    private static let emptyBotsChinese = "还没有 Bot，点右上角的 + 新建一个"

    static func run() {
        statesResolveDistinctly()
        topBarPlusKeepsItsColours()
        topBarPlusReadsTheSharedAppearance()
        topBarPlusIsTheOnlyCreationEntry()
        emptyStateIsStaticAndLocalized()
        for scheme in [ThemeScheme.light, .dark] {
            print("New Bot contrast — \(scheme == .dark ? "dark" : "light")")
            // The bar's own background: sampled from the running app's
            // navigation bar in both schemes (#F7F7F7 / #141414).
            let bar = ThemePalette.canvas.value(for: scheme)
            for state in [NewBotButtonState.ready, .creating, .notReady] {
                let appearance = NewBotButtonAppearance.resolve(state, scheme: scheme)
                let barGlyph = appearance.barGlyph.contrastRatio(against: bar)
                print(String(
                    format: "  toolbar plus %-8@ bare+#%06X on bar #%06X %.2f:1 (glyph, floor %.1f)",
                    stateName(state) as NSString,
                    appearance.barGlyph.hex, bar.hex, barGlyph, graphicFloor
                ))
                precondition(barGlyph >= graphicFloor, "\(stateName(state)) bare navigation plus is \(barGlyph):1 on the bar in \(scheme); a glyph needs \(graphicFloor):1")

                if let spinner = appearance.barSpinner {
                    let barSpinner = spinner.contrastRatio(against: bar)
                    print(String(
                        format: "               bare spinner #%06X on bar #%06X %.2f:1 (glyph, floor %.1f)",
                        spinner.hex, bar.hex, barSpinner, graphicFloor
                    ))
                    precondition(barSpinner >= graphicFloor, "\(stateName(state)) bare navigation spinner is \(barSpinner):1 on the bar in \(scheme); a glyph needs \(graphicFloor):1")
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

            // Creating keeps the brand glyph and refuses taps without reading
            // as disabled.
            precondition(creating.barGlyph == ThemePalette.brand.value(for: scheme))
            precondition(!creating.acceptsTaps && !creating.readsAsDisabled && creating.announcesProgress)
            precondition(creating.barGlyph == ready.barGlyph, "creating must not grey the plus out")

            // The navigation bar draws the same states as bare colours on the
            // bar: brand for ready and creating, muted for not ready, and the
            // bare spinner while creating. White is never used on the bar.
            precondition(ready.barGlyph == ThemePalette.brand.value(for: scheme))
            precondition(notReady.barGlyph == ThemePalette.muted.value(for: scheme))
            precondition(ready.barSpinner == nil && notReady.barSpinner == nil)
            precondition(creating.barSpinner == ThemePalette.brand.value(for: scheme))
            precondition(ready.barGlyph != ThemePalette.onBrand.value(for: scheme), "white cannot sit on the navigation bar")

            precondition(!notReady.acceptsTaps && notReady.readsAsDisabled && !notReady.announcesProgress)
            precondition(ready.acceptsTaps && !ready.readsAsDisabled && !ready.announcesProgress)
        }
    }

    /// The plus is disabled for VoiceOver when not ready. SwiftUI's `.plain`
    /// button style dims a disabled label toward the bar; `NewBotButtonStyle`
    /// keeps the colours the test measures.
    private static func topBarPlusKeepsItsColours() {
        let source = agentPageSource()
        precondition(source.contains(".buttonStyle(NewBotButtonStyle())"), "The New Bot plus lost its non-dimming button style")
    }

    /// The sole top-bar plus reads the one appearance value annotated as
    /// `NewBotButtonAppearance`, and uses its colours and flags. It must not
    /// name a colour of its own (the build-8 defect was a hardcoded
    /// `Theme.brand` plus) and must not paint a disc (build 9's defect).
    private static func topBarPlusReadsTheSharedAppearance() {
        let source = agentPageSource()

        let shared = section("private var newBotAppearance", in: source)
        precondition(shared.contains(": NewBotButtonAppearance"), "newBotAppearance is not typed as NewBotButtonAppearance")
        precondition(shared.contains(".resolve(newBotState, scheme:"), "newBotAppearance no longer resolves from the state and scheme")
        precondition(occurrences(of: ".resolve(newBotState", in: source) == 1,
                     "AgentPage must resolve the appearance once, in newBotAppearance")
        precondition(occurrences(of: "NewBotButtonAppearance.resolve(", in: source) == 0,
                     "The plus resolved its own appearance instead of reading newBotAppearance")

        let bar = section("private var newBotBarButton", in: source)
        precondition(!bar.isEmpty, "Could not find the New Bot plus in AgentPage")
        for token in ["newBotAppearance.acceptsTaps", "newBotAppearance.readsAsDisabled",
                      "newBotAccessibilityHint", "newBotAccessibilityValue"] {
            precondition(bar.contains(token), "The plus does not read \(token) from the shared appearance")
        }
        precondition(bar.contains(".disabled(newBotAppearance.readsAsDisabled)"),
                     "The plus does not disable itself from the shared appearance")
        for token in ["newBotAppearance.barGlyph.color", "newBotAppearance.barSpinner"] {
            precondition(bar.contains(token), "The plus does not read \(token) from the shared appearance")
        }

        // A navigation bar takes a bare glyph: no disc, no fill, and no colour
        // of its own.
        precondition(!bar.contains("Theme."), "The navigation bar plus hardcodes a Theme colour again")
        precondition(!bar.contains("Color(") && !bar.contains("Color."), "The navigation bar plus builds a colour of its own")
        precondition(!bar.contains("Circle("), "The navigation bar plus draws a disc again")
        precondition(!bar.contains(".fill("), "The navigation bar plus paints a fill again")
        precondition(!bar.contains(".background("), "The navigation bar plus draws a background again")
        precondition(bar.contains("Image(systemName: \"plus\")"), "The navigation bar lost its plus glyph")
        precondition(bar.contains("BareNavigationSpinner(color: spinner.color)"), "The navigation bar plus does not draw the full-opacity bare spinner from the shared appearance")
        precondition(!bar.contains("ProgressView()"), "The navigation bar spinner faded its arc below the glyph floor again")
        precondition(bar.contains(".frame(width: 44, height: 44)"), "The top-bar plus lost its 44×44 hit target")

        // Accessibility follows the appearance, not a second state read.
        precondition(!source.contains("newBotState == .creating ? Text("), "The plus describes creating from the raw state instead of the appearance")
        precondition(source.contains("announcesProgress ? Text(\"In progress\")"), "Creating no longer announces progress")
    }

    /// One creation entry: the top-bar plus. No list row or pinned row, empty
    /// or not, and no second `showNewBot` action.
    private static func topBarPlusIsTheOnlyCreationEntry() {
        let source = agentPageSource()
        precondition(!source.contains("newBotRow"), "A New Bot list row came back")
        precondition(!source.contains("newBotPinned"), "A pinned New Bot row came back")
        precondition(!source.contains("Text(\"New Bot\")"), "A full-width New Bot label came back")
        precondition(occurrences(of: "guard newBotAppearance.acceptsTaps else { return }", in: source) == 1,
                     "There must be exactly one action that opens New Bot")
        precondition(source.contains("if page == .chats {\n                    newBotToolbarItem"),
                     "The top-bar plus is no longer mounted on the Bots page")
        precondition(occurrences(of: "private var newBotBarButton", in: source) == 1,
                     "The top-bar plus is not the single create entry")
    }

    /// The empty Bots sentence is a plain, centred `Text` shown only for an
    /// empty list, and it carries both the English source and the Chinese
    /// translation.
    private static func emptyStateIsStaticAndLocalized() {
        let source = agentPageSource()
        let empty = block("if store.botsList.isEmpty {", in: source)
        precondition(!empty.isEmpty, "The empty Bots sentence is gone")
        precondition(empty.contains("Text(\"\(emptyBotsEnglish)\")"), "The empty Bots sentence lost its exact English copy")
        precondition(!empty.contains("Button"), "The empty Bots sentence became a button")
        precondition(!empty.contains("NavigationLink"), "The empty Bots sentence became a link")
        precondition(!empty.contains("onTapGesture"), "The empty Bots sentence became tappable")
        precondition(!empty.contains("showNewBot"), "The empty Bots sentence opens New Bot")
        precondition(!empty.contains("accessibilityAddTraits"), "The empty Bots sentence adds an accessibility trait")
        precondition(!empty.contains("isButton"), "The empty Bots sentence reads as a button")

        guard let data = try? Data(contentsOf: URL(fileURLWithPath: "nuphos-ios/Localizable.xcstrings")),
              let catalog = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = catalog["strings"] as? [String: Any],
              let entry = strings[emptyBotsEnglish] as? [String: Any],
              let localizations = entry["localizations"] as? [String: Any] else {
            preconditionFailure("The empty Bots sentence is missing from Localizable.xcstrings")
        }
        precondition(stringUnit(localizations["zh-Hans"]) == emptyBotsChinese,
                     "The empty Bots sentence lost its zh-Hans copy")
        precondition(stringUnit(localizations["en"]) == emptyBotsEnglish,
                     "The empty Bots sentence lost its English copy")
    }

    private static func stringUnit(_ localization: Any?) -> String? {
        guard let localization = localization as? [String: Any],
              let unit = localization["stringUnit"] as? [String: Any] else { return nil }
        return unit["value"] as? String
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

    /// The brace-balanced block beginning at `marker`.
    private static func block(_ marker: String, in source: String) -> String {
        guard let start = source.range(of: marker) else { return "" }
        var depth = 0
        var sawBrace = false
        var index = start.lowerBound
        while index < source.endIndex {
            let character = source[index]
            if character == "{" {
                depth += 1
                sawBrace = true
            } else if character == "}" {
                depth -= 1
                if sawBrace && depth == 0 {
                    return String(source[start.lowerBound...index])
                }
            }
            index = source.index(after: index)
        }
        return String(source[start.lowerBound...])
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
