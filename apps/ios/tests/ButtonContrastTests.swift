import Foundation

/// Pins the colours every button role draws, in both schemes, and keeps those
/// colours out of button styling by hand.
///
/// The ratios use the production palette the views draw with
/// (`ThemePalette`), so they measure the same values as the running app.
/// Body text and text inside a button need 4.5:1 (WCAG 2.2 AA 1.4.3); a glyph
/// or icon-only button needs 3:1 (1.4.11). `Theme.muted` is deliberately not a
/// button text colour: it measures 3.4–3.7:1 on the surfaces it sits on.
enum ButtonContrastTests {
    private static let textFloor = 4.5
    private static let graphicFloor = 3.0
    /// A disabled primary must keep a visible shape on the card and the login
    /// canvas. This is a product floor, not a WCAG text floor; inactive
    /// controls are exempt from 1.4.3/1.4.11.
    private static let shapeFloor = 1.2

    static func run() {
        paletteRolesKeepTheirFloors()
        buttonStylingKeepsToThePalette()
        print("Button contrast passed")
    }

    private static func paletteRolesKeepTheirFloors() {
        for scheme in [ThemeScheme.light, .dark] {
            let name = scheme == .dark ? "dark" : "light"
            print("Button contrast — \(name)")
            let canvas = ThemePalette.canvas.value(for: scheme)
            let surface = ThemePalette.surface.value(for: scheme)
            let chatCanvas = ThemePalette.chatCanvas.value(for: scheme)
            let chatSurface = ThemePalette.chatSurface.value(for: scheme)
            let bubble = ThemePalette.bubble.value(for: scheme)
            let heading = ThemePalette.heading.value(for: scheme)
            let body = ThemePalette.body.value(for: scheme)

            // Plain and prominent buttons on every surface a button sits on.
            for (surfaceName, background) in [
                ("canvas", canvas), ("surface", surface), ("chatCanvas", chatCanvas),
                ("chatSurface", chatSurface), ("bubble", bubble),
            ] {
                check(heading, background, textFloor, "heading button", surfaceName, scheme)
                check(body, background, textFloor, "plain-text button", surfaceName, scheme)
                // The same body colour is the verb/glyph on icon-only controls.
                check(body, background, graphicFloor, "icon button glyph", surfaceName, scheme)
            }

            // Brand fill: the prominent primary action in both schemes.
            check(ThemePalette.onBrand.value(for: scheme), ThemePalette.brand.value(for: scheme),
                  textFloor, "primary button label", "brand fill", scheme)

            // Disabled primary: the label clears 4.5:1, and the brand tint
            // keeps the shape visible on the surfaces it can sit on.
            let disabledFill = ThemePalette.primaryButtonDisabledFill.value(for: scheme)
            check(ThemePalette.primaryButtonDisabledForeground.value(for: scheme),
                  disabledFill, textFloor, "disabled primary label", "disabled fill", scheme)
            for (surfaceName, background) in [("surface", surface), ("canvas", canvas)] {
                checkShape(disabledFill, background, shapeFloor,
                           "disabled primary shape", surfaceName, scheme)
            }
            checkBrandTint(disabledFill, brand: ThemePalette.brand.value(for: scheme), scheme)

            // Capsule and chip controls in the transcript.
            check(body, ThemePalette.threadCapsuleFill.value(for: scheme),
                  textFloor, "thread capsule label", "capsule fill", scheme)
            check(heading, bubble, textFloor, "selected chip label", "bubble", scheme)

            // The two non-standard fills with their own measured labels.
            check(ThemePalette.newBotNotReadyForeground.value(for: scheme),
                  ThemePalette.newBotNotReadyFill.value(for: scheme),
                  textFloor, "New Bot not-ready label", "not-ready fill", scheme)

            // Link-styled and warning-styled buttons in the transcript.
            check(ThemePalette.brandText.value(for: scheme), surface,
                  textFloor, "brand text button", "surface", scheme)
            check(ThemePalette.warning.value(for: scheme), chatCanvas,
                  textFloor, "warning status button", "chatCanvas", scheme)
            check(ThemePalette.warning.value(for: scheme), surface,
                  textFloor, "warning status button", "surface", scheme)
            check(ThemePalette.danger.value(for: scheme), surface,
                  textFloor, "spent-limit label", "surface", scheme)
        }
    }

    private static func checkShape(
        _ fill: RGBColor,
        _ background: RGBColor,
        _ floor: Double,
        _ role: String,
        _ surface: String,
        _ scheme: ThemeScheme
    ) {
        let ratio = fill.contrastRatio(against: background)
        print(String(
            format: "  %-26@ #%06X on %-14@ #%06X %.2f:1 (shape floor %.1f)",
            role as NSString, fill.hex, surface as NSString, background.hex,
            ratio, floor
        ))
        precondition(
            ratio >= floor,
            "\(role) is \(ratio):1 on the \(surface) in \(scheme); needs \(floor):1"
        )
    }

    /// The disabled fill must read as brand, not as a neutral grey: a grey
    /// vanishes into the card even when its luminance ratio is close.
    private static func checkBrandTint(
        _ fill: RGBColor,
        brand: RGBColor,
        _ scheme: ThemeScheme
    ) {
        let fillChroma = chroma(fill)
        let fillHue = hue(fill)
        let brandHue = hue(brand)
        let delta = hueDistance(fillHue, brandHue)
        print(String(
            format: "  disabled fill #%06X hue %.1f°, chroma %.3f; brand hue %.1f° (delta %.1f°)",
            fill.hex, fillHue, fillChroma, brandHue, delta
        ))
        precondition(
            fillChroma >= 0.05,
            "The disabled fill #\(String(format: "%06X", fill.hex)) is too neutral in \(scheme); keep the brand tint"
        )
        precondition(
            delta <= 5,
            "The disabled fill hue is \(delta)° from brand in \(scheme); keep the brand tint"
        )
    }

    private static func components(_ color: RGBColor) -> (r: Double, g: Double, b: Double) {
        (
            Double((color.hex >> 16) & 0xFF) / 255,
            Double((color.hex >> 8) & 0xFF) / 255,
            Double(color.hex & 0xFF) / 255
        )
    }

    private static func chroma(_ color: RGBColor) -> Double {
        let c = components(color)
        return max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b))
    }

    private static func hue(_ color: RGBColor) -> Double {
        let c = components(color)
        let maximum = max(c.r, max(c.g, c.b))
        let minimum = min(c.r, min(c.g, c.b))
        let delta = maximum - minimum
        guard delta > 0 else { return 0 }
        var value: Double
        if maximum == c.r {
            value = ((c.g - c.b) / delta).truncatingRemainder(dividingBy: 6)
        } else if maximum == c.g {
            value = (c.b - c.r) / delta + 2
        } else {
            value = (c.r - c.g) / delta + 4
        }
        value *= 60
        return value < 0 ? value + 360 : value
    }

    private static func hueDistance(_ first: Double, _ second: Double) -> Double {
        let difference = abs(first - second).truncatingRemainder(dividingBy: 360)
        return min(difference, 360 - difference)
    }

    private static func check(
        _ foreground: RGBColor,
        _ background: RGBColor,
        _ floor: Double,
        _ role: String,
        _ surface: String,
        _ scheme: ThemeScheme
    ) {
        let ratio = foreground.contrastRatio(against: background)
        print(String(
            format: "  %-26@ #%06X on %-14@ #%06X %.2f:1 (floor %.1f)",
            role as NSString, foreground.hex, surface as NSString, background.hex,
            ratio, floor
        ))
        precondition(
            ratio >= floor,
            "\(role) is \(ratio):1 on the \(surface) in \(scheme); needs \(floor):1"
        )
    }

    /// No button label or glyph may name a colour literal, and no clickable
    /// label may fall back to `Theme.muted`. The scan walks brace-balanced
    /// `Button { … }` / `Button("…")` blocks and custom `ButtonStyle` bodies;
    /// the few deliberate exceptions carry a `palette-exempt:` comment on the
    /// line.
    private static func buttonStylingKeepsToThePalette() {
        let files = swiftFiles(under: "nuphos-ios/Views")
        precondition(!files.isEmpty, "No view sources found to scan")
        var scanned = 0
        for file in files {
            let relative = file.replacingOccurrences(of: "nuphos-ios/Views/", with: "")
            // These draw media or a remote desktop on top of the picture,
            // never app chrome; their white-on-black controls are intentional.
            if ["Desktop/DesktopScreen.swift", "Chat/MediaPager.swift", "Chat/TransferCard.swift"].contains(relative) {
                continue
            }
            guard let source = try? String(contentsOfFile: file, encoding: .utf8) else { continue }
            for block in buttonBlocks(in: source) {
                let start = block.text.range(of: "Button")?.lowerBound ?? block.text.startIndex
                let body = String(block.text[start...])
                for line in body.components(separatedBy: "\n") {
                    if line.contains("palette-exempt:") { continue }
                    if line.contains("Color.clear") { continue }
                    for pattern in literalPatterns where line.range(of: pattern, options: .regularExpression) != nil {
                        preconditionFailure(
                            "\(relative):\(block.line) names a colour literal in button styling (\(pattern)): \(line.trimmingCharacters(in: .whitespaces))"
                        )
                    }
                    if line.contains("foregroundStyle(Theme.muted)") || line.contains("tint(Theme.muted)") {
                        preconditionFailure(
                            "\(relative):\(block.line) uses Theme.muted as clickable text; use Theme.body: \(line.trimmingCharacters(in: .whitespaces))"
                        )
                    }
                }
                scanned += 1
            }
        }
        precondition(scanned > 80, "Only scanned \(scanned) button blocks; the source scan is not seeing the views")
        print("Button styling scan passed: \(scanned) button blocks across \(files.count) view files")
    }

    private static let literalPatterns = [
        "Color\\.(white|black|red|green|blue|orange|yellow|gray|secondary)\\b",
        "\\.(foregroundStyle|tint|background)\\(\\.(white|black|red|green|blue|orange|yellow|gray)\\b",
        "Color\\((red:|white:|hex:|uiColor:|\")",
        "UIColor\\.(system)?(Red|Green|Blue|Orange|Yellow|Gray|White|Black)\\b",
        "systemGray",
    ]

    private struct ButtonBlock {
        let line: Int
        let text: String
    }

    private static func buttonBlocks(in source: String) -> [ButtonBlock] {
        let lines = source.components(separatedBy: "\n")
        var blocks: [ButtonBlock] = []
        var index = 0
        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            guard isButtonStart(trimmed) else {
                index += 1
                continue
            }
            var collected = [lines[index]]
            var depth = braces(in: lines[index])
            var next = index + 1
            while depth > 0, next < lines.count, next < index + 120 {
                collected.append(lines[next])
                depth += braces(in: lines[next])
                next += 1
            }
            while next < lines.count,
                  lines[next].trimmingCharacters(in: .whitespaces).hasPrefix(".") {
                collected.append(lines[next])
                next += 1
            }
            blocks.append(ButtonBlock(line: index + 1, text: collected.joined(separator: "\n")))
            index = max(next, index + 1)
        }
        return blocks
    }

    private static func isButtonStart(_ line: String) -> Bool {
        if line.contains("Button(") { return true }
        if line.range(of: "\\bButton\\s*\\{", options: .regularExpression) != nil { return true }
        if line.contains(": ButtonStyle") || line.range(of: "\\bButtonStyle\\s*\\{", options: .regularExpression) != nil {
            return true
        }
        return false
    }

    private static func braces(in line: String) -> Int {
        line.reduce(0) { total, character in
            if character == "{" { return total + 1 }
            if character == "}" { return total - 1 }
            return total
        }
    }

    private static func swiftFiles(under root: String) -> [String] {
        guard let enumerator = FileManager.default.enumerator(atPath: root) else { return [] }
        return enumerator.compactMap { entry in
            guard let relative = entry as? String, relative.hasSuffix(".swift") else { return nil }
            return root + "/" + relative
        }.sorted()
    }
}
