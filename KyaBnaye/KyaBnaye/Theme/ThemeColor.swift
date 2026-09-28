import SwiftUI

// Palette: "Haldi & Masala" (chosen)
//
// Rationale: the app is opened by someone hungry and often tired, so the chrome should feel
// like a warm kitchen rather than a productivity tool. A cream "atta" background and cocoa
// text keep reading calm, a roasted-masala terracotta carries every tappable accent, and
// turmeric is reserved for soft decorative fills, because yellow cannot carry text at
// 4.5:1 on cream. Dark mode swaps to a roasted-brown canvas with a saffron accent, not
// neutral grey, so the warmth survives at night. Food photos stay the loudest element.
//
// Alternative considered: "Curry Leaf & Coconut", a deep curry-leaf green primary on
// coconut white with kokum-red accents. Rejected because a green primary collides with
// the green used for "Plenty" and "Want this", which would blur semantic meaning, and it
// reads as a health app rather than a home kitchen.
//
// Contract: every text role (text, accent, stock, swipe) meets WCAG AA (>= 4.5:1) on both
// `background` and `surface` in light and dark mode, enforced by `ThemeContrastTests`.
// Semantic colours are never the only signal: pair them with the symbol and title from
// `SemanticAppearance`.

/// A named colour token backed by a light/dark colour set in `Assets.xcassets`.
enum ThemeColor: String, CaseIterable, Sendable {
    /// Tappable accents, links and the global tint (masala terracotta / saffron).
    case accent = "AccentColor"
    /// Screen canvas.
    case background = "Background"
    /// Cards and grouped content that sit on the canvas.
    case surface = "Surface"
    /// Headlines and body text.
    case textPrimary = "TextPrimary"
    /// Supporting text such as captions and explanations.
    case textSecondary = "TextSecondary"
    /// Text and icons drawn on an `accent` fill.
    case onAccent = "OnAccent"
    /// Decorative fills only (halos, highlights); never used for text.
    case turmeric = "Turmeric"
    /// Stock level "Plenty".
    case stockPlenty = "StockPlenty"
    /// Stock level "Low".
    case stockLow = "StockLow"
    /// Stock level "Out".
    case stockOut = "StockOut"
    /// Swipe right, "Want this".
    case swipeWant = "SwipeWant"
    /// Swipe left, "Not today".
    case swipeSkip = "SwipeSkip"
    /// "Never show" this dish again.
    case swipeNever = "SwipeNever"

    /// The SwiftUI colour, resolved from the asset catalog for the current appearance.
    var color: Color { Color(rawValue) }
}
