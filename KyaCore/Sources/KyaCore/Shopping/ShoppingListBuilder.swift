import Foundation

/// The items bought from one ``BuyFrom`` vendor, as shown by one section of
/// the Shopping screen.
public struct ShoppingVendorGroup: Sendable, Hashable {
    /// Where these items are bought.
    public let vendor: BuyFrom

    /// The items, in the order they appeared in the grouped input.
    public let items: [ShoppingItem]

    /// Creates a vendor group.
    ///
    /// - Parameters:
    ///   - vendor: Where these items are bought.
    ///   - items: The items, in display order.
    public init(vendor: BuyFrom, items: [ShoppingItem]) {
        self.vendor = vendor
        self.items = items
    }
}

/// Builds the auto-generated portion of the shopping list (F6 in `AGENTS.md`
/// section 3): Low/Out pantry items, plus missing ingredients for recipes the
/// user explicitly asked to shop for. Manual entries are appended by the
/// caller — this builder only handles the two auto-derived sources.
///
/// Stateless and pure apart from the injected id source.
public struct ShoppingListBuilder: Sendable {
    /// Creates a builder.
    public init() {}

    /// Builds the new auto-generated shopping items.
    ///
    /// Output order is deterministic: first one row per non-``StockLevel/plenty``
    /// pantry item in `pantry` order (reason ``ShoppingReason/out`` or
    /// ``ShoppingReason/low``), then one ``ShoppingReason/recipe`` row per
    /// unavailable required ingredient in recipe order, then line order.
    ///
    /// Rules:
    /// - A pantry item whose ingredient is not in `ingredientsById` is skipped.
    /// - A recipe ingredient is skipped when
    ///   ``IngredientAvailability/isAvailable(ingredientId:role:pantry:)`` says
    ///   it is available; an id unknown to the catalog is still listed.
    /// - An ingredient id is listed at most once, and never when an
    ///   **unchecked** item in `existingItems` already carries it. Checked
    ///   items and free-typed (`ingredientId == nil`) items never block.
    ///
    /// Postconditions: every returned item has a non-`nil` ``ShoppingItem/ingredientId``,
    /// no ``ShoppingItem/customName``, `isChecked == false` and `createdAt == now`;
    /// `existingItems` are never returned; `nextId` is called exactly once per
    /// returned item, in output order.
    ///
    /// - Parameters:
    ///   - pantry: Current pantry records. Expected to hold at most one record
    ///     per ingredient id; if an id repeats, the last record decides
    ///     recipe availability and only the first can produce a pantry row.
    ///   - ingredientsById: The catalog, keyed by ``Ingredient/id``.
    ///   - existingItems: The current shopping list, so an ingredient already
    ///     on it isn't added twice.
    ///   - recipesToShopFor: Recipes the user asked to shop for, in order.
    ///   - now: Timestamp stamped on every new item.
    ///   - nextId: Supplies a fresh item id (e.g. a UUID generator) — `KyaCore`
    ///     has no opinion on id strategy.
    /// - Returns: The new items to add, in the order described above.
    public func build(
        pantry: [PantryItem],
        ingredientsById: [String: Ingredient],
        existingItems: [ShoppingItem],
        recipesToShopFor: [Recipe],
        now: Date,
        nextId: () -> String
    ) -> [ShoppingItem] {
        var alreadyListed = Set(
            existingItems.lazy.filter { !$0.isChecked }.compactMap(\.ingredientId))
        let pantryById = Dictionary(pantry.map { ($0.ingredientId, $0) }) { _, last in last }

        var result: [ShoppingItem] = []

        for item in pantry {
            if item.level == .plenty { continue }
            if ingredientsById[item.ingredientId] == nil { continue }
            if !alreadyListed.insert(item.ingredientId).inserted { continue }
            result.append(
                ShoppingItem.catalogBacked(
                    id: nextId(),
                    ingredientId: item.ingredientId,
                    reason: item.level == .out ? .out : .low,
                    recipeId: nil,
                    createdAt: now
                ))
        }

        for recipe in recipesToShopFor {
            for line in recipe.requiredIngredients {
                let available = IngredientAvailability.isAvailable(
                    ingredientId: line.ingredientId,
                    role: ingredientsById[line.ingredientId]?.role,
                    pantry: pantryById
                )
                if available { continue }
                if !alreadyListed.insert(line.ingredientId).inserted { continue }
                result.append(
                    ShoppingItem.catalogBacked(
                        id: nextId(),
                        ingredientId: line.ingredientId,
                        reason: .recipe,
                        recipeId: recipe.id,
                        createdAt: now
                    ))
            }
        }

        return result
    }

    /// Groups items by where the household buys them ("Sabziwala / Kirana /
    /// Dairy / Other", `AGENTS.md` section 4) for the Shopping screen.
    ///
    /// Postconditions: exactly one group per ``BuyFrom`` case, in
    /// `BuyFrom.allCases` order, including empty groups; every input item
    /// appears in exactly one group; input order is preserved within a group.
    /// Free-typed items and ids unknown to the catalog go to ``BuyFrom/other``.
    ///
    /// - Parameters:
    ///   - items: The items to group.
    ///   - ingredientsById: The catalog, keyed by ``Ingredient/id``.
    /// - Returns: One group per vendor, in `BuyFrom.allCases` order.
    public func groupByVendor(
        items: [ShoppingItem],
        ingredientsById: [String: Ingredient]
    ) -> [ShoppingVendorGroup] {
        let byVendor = Dictionary(grouping: items) { item in
            item.ingredientId.flatMap { ingredientsById[$0]?.buyFrom } ?? .other
        }
        return BuyFrom.allCases.map { vendor in
            ShoppingVendorGroup(vendor: vendor, items: byVendor[vendor] ?? [])
        }
    }
}
