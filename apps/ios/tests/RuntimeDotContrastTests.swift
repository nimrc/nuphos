import Foundation

/// Pins the Cloud runtime status dot in both states and schemes.
///
/// The dot is a non-text graphic, so each state must clear 3:1 (WCAG 2.2 AA
/// 1.4.11) against both backgrounds it is drawn on: the page `canvas` and the
/// row `surface`. Every colour comes from `ThemePalette`; none is copied from
/// the design note.
///
/// The states also differ by shape, not only by colour: both are filled
/// circles, and the offline dot carries one diagonal slash. That is checked
/// against `RuntimeDotState`, the same state and geometry the view draws.
enum RuntimeDotContrastTests {
    private static let graphicFloor = 3.0

    static func run() {
        shapeDistinguishesTheStatesWithoutColour()
        dotReadsThePaletteAndKeepsItsLabels()
        for scheme in [ThemeScheme.light, .dark] {
            print("Runtime dot contrast — \(scheme == .dark ? "dark" : "light")")
            let canvas = ThemePalette.canvas.value(for: scheme)
            let surface = ThemePalette.surface.value(for: scheme)
            for (name, colour) in [("online", ThemePalette.dotOnline), ("offline", ThemePalette.dotOffline)] {
                let dot = colour.value(for: scheme)
                for (backgroundName, background) in [("canvas", canvas), ("surface", surface)] {
                    let ratio = dot.contrastRatio(against: background)
                    print(String(
                        format: "  dot %-7@ #%06X on %-7@ #%06X %.2f:1 (graphic, floor %.1f)",
                        name as NSString, dot.hex, backgroundName as NSString, background.hex,
                        ratio, graphicFloor
                    ))
                    precondition(ratio >= graphicFloor, "The \(name) dot is \(ratio):1 on the \(backgroundName) in \(scheme); a graphic needs \(graphicFloor):1")
                }
            }
        }
        print("Runtime dot contrast passed")
    }

    /// Online and offline must not rely on colour alone: the offline dot draws
    /// a slash, the online dot does not, and both are filled 8-point circles.
    private static func shapeDistinguishesTheStatesWithoutColour() {
        let online = RuntimeDotState(online: true)
        let offline = RuntimeDotState(online: false)
        precondition(online == .online && offline == .offline)
        precondition(online.isFilled && offline.isFilled, "both states must be filled circles")
        precondition(!online.drawsSlash, "the online dot must not draw the offline slash")
        precondition(offline.drawsSlash, "the offline dot lost its slash")
        precondition(online.diameter == 8 && offline.diameter == 8, "the dot is 8 points")
        precondition(offline.slashWidth == 1.5, "the slash is 1.5 points")
        precondition(offline.slashAngleDegrees == 45, "the slash is diagonal")
    }

    /// The view draws the shared palette slots, never the system greens and
    /// reds, and the row keeps each state's own VoiceOver label.
    private static func dotReadsThePaletteAndKeepsItsLabels() {
        let dot = source("nuphos-ios/Views/Home/RuntimeStatusDot.swift")
        precondition(dot.contains("Theme.dotOnline") && dot.contains("Theme.dotOffline"),
                     "The status dot does not draw from Theme.dotOnline/dotOffline")
        precondition(!dot.contains("Color.green") && !dot.contains("Color.red"),
                     "The status dot names a system green or red again")
        precondition(dot.contains("state.drawsSlash"), "The status dot does not draw the offline slash")

        let row = source("nuphos-ios/Views/Home/RuntimePickerSheet.swift")
        precondition(row.contains("RuntimeStatusDot(online: reachable)"),
                     "SelectorAgentRow no longer draws the shared status dot")
        precondition(row.contains(".accessibilityLabel(reachable ? Text(\"Online\") : Text(\"Offline\"))"),
                     "The status dot lost its per-state VoiceOver label")
        precondition(!row.contains("Circle().fill(reachable ? Color.green : Color.red)"),
                     "SelectorAgentRow paints the status dot itself again")

        // The Runtimes page shows the same dot by reusing the same row.
        let page = source("nuphos-ios/Views/Home/RuntimesPage.swift")
        precondition(page.contains("SelectorAgentRow("), "The Runtimes page stopped reusing the shared row")
        precondition(!page.contains("RuntimeStatusDot("), "The Runtimes page draws a second status dot")
    }

    private static func source(_ path: String) -> String {
        (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
    }
}
