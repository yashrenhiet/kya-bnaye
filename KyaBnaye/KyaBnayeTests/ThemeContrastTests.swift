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
