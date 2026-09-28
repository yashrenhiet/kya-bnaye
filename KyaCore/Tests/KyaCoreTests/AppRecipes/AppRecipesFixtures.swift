import Foundation
import KyaCore

/// A tiny catalog and recipe book for the recipe-book, cooking and history tests.
enum AppRecipesFixtures {
    /// A fixed instant.
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
    static let oil = Ingredient(
        id: "oil", name: "Oil", category: .oilGhee, role: .staple, buyFrom: .kirana)
    static let coriander = Ingredient(
        id: "coriander", name: "Coriander", category: .sabzi, role: .optional,
        buyFrom: .sabziwala, shelfLifeDays: 3)
    static let eggs = Ingredient(
        id: "eggs", name: "Eggs", category: .other, role: .core, buyFrom: .kirana,
        shelfLifeDays: 14)
    static let honey = Ingredient(
        id: "honey", name: "Honey", category: .other, role: .flavor, buyFrom: .kirana)
    static let banana = Ingredient(
        id: "banana", name: "Banana", category: .fruit, role: .core, buyFrom: .sabziwala,
        shelfLifeDays: 4)

    static let catalog = [potato, peas, paneer, jeera, salt, oil, coriander, eggs, honey, banana]
    static let catalogById = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })

    static let tags = DishTags(
        region: .north, dishType: .drySabzi, flavours: [.savoury], heaviness: .medium,
        protein: .vegOnly)

    /// Aloo Matar: potato, peas, jeera (required), salt + oil (staples),
    /// coriander (optional line).
    static let alooMatar = Recipe(
        id: "aloo_matar", name: "Aloo Matar", mealTypes: [.lunch, .dinner], minutes: 25,
        base: .roti,
        ingredients: [
            line("potato"), line("peas"), line("jeera"), line("salt"), line("oil"),
            line("coriander", optional: true),
        ],
        steps: ["Chop.", "Cook."], tags: tags, source: .seed)

    static func line(_ id: String, optional: Bool = false) -> RecipeIngredient {
        RecipeIngredient(ingredientId: id, quantityText: "1", isOptional: optional)
    }

    static func pantry(_ entries: [(String, StockLevel)]) -> [String: PantryItem] {
        Dictionary(
            uniqueKeysWithValues: entries.map {
                ($0.0, PantryItem(ingredientId: $0.0, level: $0.1, updatedAt: now))
            })
    }

    static func recipe(
        _ id: String,
        name: String? = nil,
        minutes: Int = 20,
        mealTypes: Set<MealType> = [.dinner],
        ingredients: [RecipeIngredient] = [line("potato")],
        isFavorite: Bool = false,
        isHidden: Bool = false
    ) -> Recipe {
        Recipe(
            id: id, name: name ?? id, mealTypes: mealTypes, minutes: minutes, base: .none,
            ingredients: ingredients, steps: ["Cook."], tags: tags, source: .user,
            isFavorite: isFavorite, isHidden: isHidden)
    }
}
