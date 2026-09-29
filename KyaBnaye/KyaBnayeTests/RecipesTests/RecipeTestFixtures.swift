import Foundation
import KyaCore
import Testing

@testable import KyaBnaye

/// A small catalog and recipe book in an in-memory store, for the Recipes, Cooking and
/// History store tests.
enum RecipeTestFixtures {
    static let now = Date(timeIntervalSince1970: 1_790_000_000)

    static let potato = Ingredient(
        id: "potato", name: "Potato", aliases: ["aloo"], category: .sabzi, role: .core,
        buyFrom: .sabziwala, shelfLifeDays: 20)
    static let peas = Ingredient(
        id: "peas", name: "Peas", aliases: ["matar"], category: .sabzi, role: .core,
        buyFrom: .sabziwala, shelfLifeDays: 4)
    static let paneer = Ingredient(
        id: "paneer", name: "Paneer", category: .dairy, role: .core, buyFrom: .dairy,
        shelfLifeDays: 3)
    static let jeera = Ingredient(
        id: "jeera", name: "Jeera", category: .masala, role: .flavor, buyFrom: .kirana)
    static let salt = Ingredient(
        id: "salt", name: "Salt", category: .masala, role: .staple, buyFrom: .kirana)

    static let tags = DishTags(
        region: .north, dishType: .drySabzi, flavours: [.savoury], heaviness: .medium,
        protein: .vegOnly)

    static func line(_ id: String, optional: Bool = false) -> RecipeIngredient {
        RecipeIngredient(ingredientId: id, quantityText: "1", isOptional: optional)
    }

    static let alooMatar = Recipe(
        id: "aloo_matar", name: "Aloo Matar", mealTypes: [.lunch, .dinner], minutes: 25,
        base: .roti, ingredients: [line("potato"), line("peas"), line("jeera"), line("salt")],
        steps: ["Chop.", "Cook."], tags: tags, source: .seed)

    static let jeeraAloo = Recipe(
        id: "jeera_aloo", name: "Jeera Aloo", mealTypes: [.lunch], minutes: 20, base: .roti,
        ingredients: [line("potato"), line("jeera"), line("salt")], steps: ["Fry.", "Serve."],
        tags: tags, source: .seed, imageAsset: "images/jeera_aloo.webp")

    static let paneerBhurji = Recipe(
        id: "paneer_bhurji", name: "Paneer Bhurji", mealTypes: [.dinner], minutes: 45,
        base: .roti, ingredients: [line("paneer"), line("peas", optional: true)],
        steps: ["Crumble.", "Fry."], tags: tags, source: .user, isFavorite: true)

    static let hiddenDish = Recipe(
        id: "hidden_dish", name: "Hidden Dish", mealTypes: [.snack], minutes: 10, base: .none,
        ingredients: [line("potato")], steps: ["Hide."], tags: tags, source: .seed,
        isHidden: true)

    /// A fresh in-memory store holding the catalog, the four recipes and `pantry`.
    static func repositories(
        pantry: [(String, StockLevel)] = [], shopping: [ShoppingItem] = [],
        logs: [MealLog] = []
    ) async throws -> RepositorySet {
        let repositories = try SwiftDataStore.inMemory().repositories
        try await repositories.ingredients.upsert([potato, peas, paneer, jeera, salt])
        try await repositories.recipes.upsert([alooMatar, jeeraAloo, paneerBhurji, hiddenDish])
        try await repositories.pantry.setLevels(
            pantry.map { PantryItem(ingredientId: $0.0, level: $0.1, updatedAt: now) })
        try await repositories.shopping.upsert(shopping)
        for log in logs { try await repositories.mealLogs.add(log) }
        return repositories
    }

    /// A Gregorian calendar in `identifier`'s time zone.
    static func calendar(_ identifier: String = "Asia/Kolkata") throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: identifier))
        return calendar
    }

    /// Sequential ids "id1", "id2"...
    @MainActor
    static func sequentialIds() -> () -> String {
        var next = 0
        return {
            next += 1
            return "id\(next)"
        }
    }
}

/// Waits (yielding) until `condition` holds, failing the test after `timeout`.
@MainActor
func recipesWaitUntil(
    timeout: Duration = .seconds(5),
    sourceLocation: SourceLocation = #_sourceLocation,
    _ condition: () -> Bool
) async {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while !condition() {
        if clock.now > deadline {
            Issue.record("timed out waiting for condition", sourceLocation: sourceLocation)
            return
        }
        try? await Task.sleep(for: .milliseconds(10))
    }
}
