import Foundation
import KyaCore

/// One row of the Shopping screen, ready to display.
struct ShoppingRow: Identifiable, Equatable, Sendable {
    /// The shopping item id.
    let id: String
    /// What to buy.
    let name: String
    /// Why it is on the list, e.g. "from: Out" or "from: Palak Paneer".
    let reasonText: String
    /// Whether it is ticked off as bought.
    let isChecked: Bool
}

/// One vendor section of the Shopping screen.
struct ShoppingSection: Identifiable, Equatable, Sendable {
    /// Where these items are bought.
    let vendor: BuyFrom
    /// The rows, in list order.
    let rows: [ShoppingRow]

    var id: BuyFrom { vendor }
}

/// Turns stored shopping items into what the Shopping screen and the share sheet show.
/// Pure, so the wording and grouping are tested without a view.
struct ShoppingPresenter: Sendable {
    /// The catalog, keyed by id.
    let ingredientsById: [String: Ingredient]
    /// Recipe display names, keyed by recipe id.
    let recipeNamesById: [String: String]

    /// The display name of `item`: its typed name, else the catalog name, else the raw id
    /// (an id the catalog no longer knows still shows something recognisable).
    func name(of item: ShoppingItem) -> String {
        item.displayName { id in ingredientsById[id]?.name ?? id }
    }

    /// Why `item` is on the list, in the words the user sees.
    func reasonText(of item: ShoppingItem) -> String {
        switch item.reason {
        case .out: String(localized: "from: Out")
        case .low: String(localized: "from: Low")
        case .recipe:
            if let name = item.recipeId.flatMap({ recipeNamesById[$0] }) {
                String(localized: "from: \(name)")
            } else {
                String(localized: "from: a recipe")
            }
        case .manual: String(localized: "added by you")
        }
    }

    /// The non-empty vendor sections, in Sabziwala / Kirana / Dairy / Other order.
    func sections(for items: [ShoppingItem]) -> [ShoppingSection] {
        ShoppingListBuilder()
            .groupByVendor(items: items, ingredientsById: ingredientsById)
            .filter { !$0.items.isEmpty }
            .map { group in
                ShoppingSection(
                    vendor: group.vendor,
                    rows: group.items.map { item in
                        ShoppingRow(
                            id: item.id, name: name(of: item), reasonText: reasonText(of: item),
                            isChecked: item.isChecked)
                    })
            }
    }

    /// The plain-text list for the share sheet: still-to-buy items grouped by vendor, one
    /// per line, ticked items left out. Empty when nothing is left to buy.
    func shareText(for items: [ShoppingItem]) -> String {
        let toBuy = items.filter { !$0.isChecked }
        guard !toBuy.isEmpty else { return "" }
        let blocks = sections(for: toBuy).map { section in
            ([section.vendor.displayName.uppercased()] + section.rows.map { "- \($0.name)" })
                .joined(separator: "\n")
        }
        return ([String(localized: "Shopping list")] + blocks).joined(separator: "\n\n")
    }
}

/// A catalog ingredient offered while typing in "Add item".
struct IngredientSuggestion: Identifiable, Equatable, Sendable {
    /// The ingredient id.
    let id: String
    /// The catalog name, e.g. "Potato".
    let name: String
    /// The alias the text matched, when it wasn't the name, e.g. "aloo".
    let matchedAlias: String?
}

/// Alias-aware autocomplete over the catalog: "alo" offers Potato (aloo).
///
/// Suggestions are only a shortcut: adding still needs an exact name or alias match
/// (the ``KyaCore/IngredientNormalizer`` key), so "rice" never silently becomes "rice flour".
enum IngredientSuggester {
    /// At most this many suggestions are offered.
    static let limit = 5

    /// Suggestions for `text`: names or aliases that start with it first, then ones that
    /// contain it, each alphabetical by name. Blank text suggests nothing.
    static func suggestions(for text: String, in catalog: [Ingredient]) -> [IngredientSuggestion] {
        let query = IngredientNormalizer.normalise(text)
        guard !query.isEmpty else { return [] }
        var ranked: [(rank: Int, suggestion: IngredientSuggestion)] = []
        for ingredient in catalog {
            guard let match = bestMatch(of: query, in: ingredient) else { continue }
            ranked.append(
                (
                    match.rank,
                    IngredientSuggestion(
                        id: ingredient.id, name: ingredient.name, matchedAlias: match.alias)
                ))
        }
        return
            ranked
            .sorted { lhs, rhs in
                lhs.rank != rhs.rank
                    ? lhs.rank < rhs.rank
                    : (lhs.suggestion.name, lhs.suggestion.id) < (
                        rhs.suggestion.name, rhs.suggestion.id
                    )
            }
            .prefix(limit)
            .map(\.suggestion)
    }

    /// Rank 0 for a prefix match, 1 for a substring match; the name wins over aliases.
    private static func bestMatch(
        of query: String, in ingredient: Ingredient
    ) -> (rank: Int, alias: String?)? {
        let candidates = [(ingredient.name, nil)] + ingredient.aliases.map { ($0, Optional($0)) }
        var best: (rank: Int, alias: String?)?
        for (text, alias) in candidates {
            let key = IngredientNormalizer.normalise(text)
            let rank: Int
            if key.hasPrefix(query) {
                rank = 0
            } else if key.contains(query) {
                rank = 1
            } else {
                continue
            }
            if best.map({ rank < $0.rank }) ?? true { best = (rank, alias) }
        }
        return best
    }
}
