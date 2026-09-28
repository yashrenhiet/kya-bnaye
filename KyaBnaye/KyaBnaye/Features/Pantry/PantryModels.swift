import Foundation
import KyaCore

/// The Pantry filter chips.
enum PantryFilter: String, CaseIterable, Identifiable, Sendable {
    /// Everything in the pantry.
    case all
    /// Items that are running low or already out.
    case low
    /// Items (not out) that expire within ``PantryRules/expiringWindowDays``, or already have.
    case expiring

    var id: Self { self }

    /// The chip label.
    var title: String {
        switch self {
        case .all: String(localized: "All")
        case .low: String(localized: "Low")
        case .expiring: String(localized: "Expiring")
        }
    }

    /// What the chip shows, for VoiceOver.
    var accessibilityHint: String {
        switch self {
        case .all: String(localized: "Shows everything in your pantry.")
        case .low: String(localized: "Shows items that are low or out.")
        case .expiring: String(localized: "Shows items that expire in the next two days.")
        }
    }
}

/// Pantry business rules that the store and its tests share.
enum PantryRules {
    /// "Expiring" means expiring within this many calendar days (or already expired).
    static let expiringWindowDays = 2

    /// Expiry badges are shown only this close to the date, so long-lasting items stay quiet.
    static let badgeWindowDays = 7

    /// Category sections in the order a household scans a kitchen: fresh first, then dry
    /// goods, then everything else.
    static let categoryOrder: [IngredientCategory] = [
        .sabzi, .fruit, .dairy, .grains, .dal, .masala, .oilGhee, .packaged, .other,
    ]

    /// The level a tap moves to: Plenty → Low → Out → Plenty. An assumed staple (no record)
    /// counts as Plenty, so its first tap marks it Low.
    static func nextLevel(after level: StockLevel?) -> StockLevel {
        switch level {
        case .plenty, nil: .low
        case .low: .out
        case .out: .plenty
        }
    }

    /// The vendor a new ingredient of `category` is most likely bought from.
    static func defaultBuyFrom(for category: IngredientCategory) -> BuyFrom {
        switch category {
        case .sabzi, .fruit: .sabziwala
        case .dairy: .dairy
        case .grains, .dal, .masala, .oilGhee, .packaged: .kirana
        case .other: .other
        }
    }
}

/// One line on the Pantry screen.
struct PantryRow: Identifiable, Equatable, Sendable {
    /// The catalog ingredient.
    let ingredient: Ingredient
    /// The stock record, or `nil` for a staple that is assumed present.
    let item: PantryItem?
    /// Calendar days until expiry (negative once expired), or `nil` with no known expiry.
    let daysUntilExpiry: Int?

    var id: String { ingredient.id }

    /// A staple with no record: assumed at home until marked otherwise.
    var isAssumedStaple: Bool { item == nil }

    /// The level to show and cycle from; an assumed staple behaves as Plenty.
    var effectiveLevel: StockLevel { item?.level ?? .plenty }

    /// The expiry badge, if the date is close enough to be worth showing.
    var expiryBadge: ExpiryBadge? {
        guard let daysUntilExpiry, effectiveLevel != .out,
            daysUntilExpiry <= PantryRules.badgeWindowDays
        else { return nil }
        return ExpiryBadge(
            daysUntilExpiry: daysUntilExpiry, isEstimated: item?.expiryIsEstimated ?? false)
    }
}

/// A titled group of rows.
struct PantrySection: Identifiable, Equatable, Sendable {
    /// The category the rows belong to.
    let category: IngredientCategory
    /// Rows sorted by ingredient name.
    let rows: [PantryRow]

    var id: IngredientCategory { category }
}

/// The short expiry label: "expired", "today", "1 day", "3 days".
struct ExpiryBadge: Equatable, Sendable {
    /// Calendar days until expiry; negative once expired.
    let daysUntilExpiry: Int
    /// Whether the date was estimated from typical shelf life.
    let isEstimated: Bool

    /// The visible label.
    var text: String {
        switch daysUntilExpiry {
        case ..<0: String(localized: "expired")
        case 0: String(localized: "today")
        case 1: String(localized: "1 day")
        default: String(localized: "\(daysUntilExpiry) days")
        }
    }

    /// The spoken label, which also says whether the date is an estimate.
    var accessibilityText: String {
        let when =
            switch daysUntilExpiry {
            case ..<0: String(localized: "Expired")
            case 0: String(localized: "Expires today")
            case 1: String(localized: "Expires in 1 day")
            default: String(localized: "Expires in \(daysUntilExpiry) days")
            }
        return isEstimated ? String(localized: "\(when), estimated") : when
    }

    /// A distinct symbol for expired items, so urgency is not shown by colour alone.
    var symbolName: String { daysUntilExpiry < 0 ? "exclamationmark.triangle" : "clock" }
}
