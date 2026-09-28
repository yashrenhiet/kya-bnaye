import Foundation
import KyaCore

// User-facing words and badge appearances for the swipe deck.

extension SwipeMode {
    /// The segmented-control title.
    var title: String {
        switch self {
        case .kitchen: String(localized: "Kitchen")
        case .craving: String(localized: "Craving")
        }
    }

    /// The other mode, for "Switch mode".
    var other: SwipeMode {
        switch self {
        case .kitchen: .craving
        case .craving: .kitchen
        }
    }
}

extension ScoredRecipe {
    /// The card badge: the Kitchen tier, or "Explore" for a Craving explore card. `nil` for
    /// an ordinary Craving card, which needs no badge.
    var badge: SemanticAppearance? {
        if let tier { return tier.appearance }
        guard isExplore else { return nil }
        return SemanticAppearance(
            title: String(localized: "Explore"), symbolName: "safari", color: .accent)
    }

    /// "Have 5 of 7 ingredients".
    var haveText: String {
        String(localized: "Have \(haveCount) of \(requiredCount) ingredients")
    }
}

extension RecipeTier {
    /// Badge appearance: symbol and title always, colour as a third cue.
    var appearance: SemanticAppearance {
        switch self {
        case .useItUp:
            SemanticAppearance(
                title: String(localized: "Use it up"), symbolName: "clock.badge.exclamationmark",
                color: .stockLow)
        case .readyNow:
            SemanticAppearance(
                title: String(localized: "Ready now"), symbolName: "checkmark.circle.fill",
                color: .stockPlenty)
        case .missing1:
            SemanticAppearance(
                title: String(localized: "Missing 1"), symbolName: "cart", color: .textSecondary)
        case .missing2:
            SemanticAppearance(
                title: String(localized: "Missing 2"), symbolName: "cart.badge.plus",
                color: .textSecondary)
        }
    }
}

/// The greeting at the top of Home, from the hour in the app's calendar.
enum HomeGreeting {
    /// "Good morning" (4–11), "Good afternoon" (12–16) or "Good evening".
    ///
    /// - Parameters:
    ///   - now: The current instant.
    ///   - calendar: Decides the hour.
    /// - Returns: The greeting.
    static func text(now: Date, calendar: Calendar) -> String {
        switch calendar.component(.hour, from: now) {
        case 4..<12: String(localized: "Good morning")
        case 12..<17: String(localized: "Good afternoon")
        default: String(localized: "Good evening")
        }
    }
}
