import Foundation
import KyaCore

/// Fixtures mirroring `legacy/packages/kya_core/test/shopping/shopping_list_builder_test.dart`.
enum ShoppingFixtures {
    static let potato = Ingredient(
        id: "potato", name: "Potato", aliases: ["aloo"], category: .sabzi, role: .core,
        buyFrom: .sabziwala, shelfLifeDays: 14)
    static let onion = Ingredient(
        id: "onion", name: "Onion", category: .sabzi, role: .core, buyFrom: .sabziwala)
    static let paneer = Ingredient(
        id: "paneer", name: "Paneer", category: .dairy, role: .core, buyFrom: .dairy,
        shelfLifeDays: 5)
    static let jeera = Ingredient(
        id: "jeera", name: "Jeera", category: .masala, role: .flavor, buyFrom: .kirana)
    static let salt = Ingredient(
        id: "salt", name: "Salt", category: .masala, role: .staple, buyFrom: .kirana)
    static let oil = Ingredient(
        id: "oil", name: "Oil", category: .oilGhee, role: .staple, buyFrom: .kirana)
    static let dragonfruit = Ingredient(
        id: "dragonfruit", name: "Dragonfruit", category: .fruit, role: .core, buyFrom: .other,
        isUserCreated: true)

    static let catalog: [String: Ingredient] = Dictionary(
        uniqueKeysWithValues: [potato, onion, paneer, jeera, salt, oil, dragonfruit].map {
            ($0.id, $0)
        })

    /// Dart `DateTime(2026, 9, 26, 19)` (local wall time).
    static func now() throws -> Date { try TestDates.local(2026, 9, 26, 19) }

    /// Dart `DateTime(2026, 9, 20, 8, 30)` (local wall time).
    static func earlier() throws -> Date { try TestDates.local(2026, 9, 20, 8, 30) }

    static func pantry(_ id: String, _ level: StockLevel) throws -> PantryItem {
        PantryItem(ingredientId: id, level: level, updatedAt: try earlier())
    }

    static func line(_ id: String, optional: Bool = false) -> RecipeIngredient {
        RecipeIngredient(ingredientId: id, quantityText: "1", isOptional: optional)
    }

    static func recipe(_ id: String, _ ingredients: [RecipeIngredient]) -> Recipe {
        Recipe(
            id: id,
            name: id,
            mealTypes: [.dinner],
            minutes: 20,
            base: .roti,
            ingredients: ingredients,
            steps: ["Cook"],
            tags: DishTags(
                region: .north, dishType: .curry, flavours: [.savoury], heaviness: .medium,
                protein: .vegOnly),
            source: .seed
        )
    }

    static func existing(
        id: String,
        ingredientId: String? = nil,
        customName: String? = nil,
        reason: ShoppingReason = .manual,
        isChecked: Bool = false
    ) throws -> ShoppingItem {
        try ShoppingItem(
            id: id, ingredientId: ingredientId, customName: customName, reason: reason,
            isChecked: isChecked, createdAt: try earlier())
    }
}

/// Deterministic id source that also records how often it was called.
final class IdCounter {
    private(set) var calls = 0

    func next() -> String {
        defer { calls += 1 }
        return "shop_\(calls)"
    }
}
