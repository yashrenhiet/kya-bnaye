import Testing
import UIKit

@testable import KyaBnaye

/// A text-colour role drawn on a canvas colour; must meet WCAG AA for normal text.
struct ContrastPair: Sendable, CustomTestStringConvertible {
    let foreground: ThemeColor
    let background: ThemeColor

    var testDescription: String { "\(foreground.rawValue) on \(background.rawValue)" }
}

struct ThemeContrastTests {
    static let textRoles: [ThemeColor] = [
        .textPrimary, .textSecondary, .accent,
        .stockPlenty, .stockLow, .stockOut,
        .swipeWant, .swipeSkip, .swipeNever,
    ]

    static let pairs: [ContrastPair] =
        textRoles.flatMap { role in
            [
                ContrastPair(foreground: role, background: .background),
                ContrastPair(foreground: role, background: .surface),
            ]
        } + [ContrastPair(foreground: .onAccent, background: .accent)]

    static let styles: [UIUserInterfaceStyle] = [.light, .dark]

    @Test("Every theme token resolves from the asset catalog", arguments: ThemeColor.allCases)
    func tokenExists(_ token: ThemeColor) {
        #expect(UIColor(named: token.rawValue, in: .main, compatibleWith: nil) != nil)
    }

    @Test("Text roles meet WCAG AA 4.5:1", arguments: pairs, styles)
    func textContrast(_ pair: ContrastPair, style: UIUserInterfaceStyle) throws {
        let foreground = try resolved(pair.foreground, style)
        let background = try resolved(pair.background, style)
        let ratio = WCAG.contrastRatio(foreground, background)
        #expect(ratio >= 4.5, "\(pair.testDescription) is \(ratio):1 in style \(style.rawValue)")
    }

    @Test("Contrast formula matches WCAG reference values")
    func formulaReference() {
        #expect(abs(WCAG.contrastRatio(.black, .white) - 21) < 0.001)
        #expect(abs(WCAG.contrastRatio(.white, .white) - 1) < 0.001)
    }

    static let canvases: [ThemeColor] = [.background, .surface]

    @Test(
        "An off chip's outline reaches 3:1 on its fill and the canvas", arguments: canvases, styles)
    @MainActor
    func chipOutline(_ canvas: ThemeColor, style: UIUserInterfaceStyle) throws {
        let under = try resolved(canvas, style)
        let outline = WCAG.over(
            try resolved(.textSecondary, style), alpha: ChipLabel.outlineOpacity, under)
        let ratio = WCAG.contrastRatio(outline, under)
        #expect(ratio >= 3, "chip outline on \(canvas.rawValue) is \(ratio):1")
    }

    @Test("A pressed primary button keeps its label at 4.5:1", arguments: canvases, styles)
    @MainActor
    func pressedPrimary(_ canvas: ThemeColor, style: UIUserInterfaceStyle) throws {
        let under = try resolved(canvas, style)
        let alpha = PrimaryButtonStyle.pressedOpacity
        let label = WCAG.over(try resolved(.onAccent, style), alpha: alpha, under)
        let fill = WCAG.over(try resolved(.accent, style), alpha: alpha, under)
        let ratio = WCAG.contrastRatio(label, fill)
        #expect(ratio >= 4.5, "pressed primary on \(canvas.rawValue) is \(ratio):1")
    }

    @Test(
        "An accent-tinted bordered button's label reaches 4.5:1 on its tinted fill",
        arguments: canvases, styles)
    func borderedAccent(_ canvas: ThemeColor, style: UIUserInterfaceStyle) throws {
        let accent = try resolved(.accent, style)
        let fill = WCAG.over(accent, alpha: 0.2, try resolved(canvas, style))
        let ratio = WCAG.contrastRatio(accent, fill)
        #expect(ratio >= 4.5, "bordered accent on \(canvas.rawValue) is \(ratio):1")
    }

    private func resolved(_ token: ThemeColor, _ style: UIUserInterfaceStyle) throws -> UIColor {
        let color = try #require(UIColor(named: token.rawValue, in: .main, compatibleWith: nil))
        return color.resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
    }
}

/// WCAG 2.2 relative luminance and contrast ratio for sRGB colours.
private enum WCAG {
    static func contrastRatio(_ first: UIColor, _ second: UIColor) -> Double {
        let lighter = max(luminance(first), luminance(second))
        let darker = min(luminance(first), luminance(second))
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// `color` drawn at `alpha` over the opaque `background` (sRGB source-over).
    static func over(_ color: UIColor, alpha: Double, _ background: UIColor) -> UIColor {
        let top = components(color)
        let bottom = components(background)
        let mix = { (index: Int) in CGFloat(alpha) * top[index] + CGFloat(1 - alpha) * bottom[index]
        }
        return UIColor(red: mix(0), green: mix(1), blue: mix(2), alpha: 1)
    }

    private static func components(_ color: UIColor) -> [CGFloat] {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return [red, green, blue]
    }

    private static func luminance(_ color: UIColor) -> Double {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    private static func linear(_ channel: CGFloat) -> Double {
        let value = Double(channel)
        return value <= 0.040_45 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }
}
