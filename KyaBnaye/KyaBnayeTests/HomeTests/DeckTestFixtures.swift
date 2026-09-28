import Foundation
import KyaCore
import Testing

@testable import KyaBnaye

/// The `KyaCore` ranker fixture kitchen (`RankerFixtures` / `RankerRecipes` in
/// `KyaCoreTests`, frozen from the Dart oracle) in an in-memory store, so the deck store can
/// be checked against the same goldens.
enum DeckTestFixtures {
    /// A Gregorian calendar in India.
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Kolkata") ?? .gmt
        return calendar
    }

    /// Wednesday 23 Sep 2026, 19:00 in ``calendar``: a weekday dinner.
    static var weekdayDinner: Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 19)) ?? .now
    }

    /// Golden K2's pantry: potato, matar, onion, tomato (plus the assumed staples).
    static let k2Pantry = ["potato", "matar", "onion", "tomato"]

    private static func item(
        _ id: String, _ name: String, _ role: IngredientRole,
        _ category: IngredientCategory = .other
    ) -> Ingredient {
        Ingredient(id: id, name: name, category: category, role: role, buyFrom: .kirana)
    }

    /// The fixture catalog.
    static let catalog: [Ingredient] = [
        item("potato", "Potato", .core, .sabzi), item("matar", "Matar", .core, .sabzi),
        item("palak", "Palak", .core, .sabzi), item("cabbage", "Cabbage", .core, .sabzi),
        item("paneer", "Paneer", .core, .dairy), item("curd", "Curd", .core, .dairy),
        item("egg", "Egg", .core), item("rice", "Rice", .core, .grains),
        item("poha", "Poha", .core, .grains), item("rava", "Rava", .core, .grains),
        item("besan", "Besan", .core, .grains), item("dosa_batter", "Dosa batter", .core),
        item("noodles", "Noodles", .core), item("toor_dal", "Toor dal", .core, .dal),
        item("rajma", "Rajma", .core, .dal), item("chana", "Kabuli chana", .core, .dal),
        item("onion", "Onion", .flavor, .sabzi), item("tomato", "Tomato", .flavor, .sabzi),
        item("ginger_garlic", "Ginger-garlic", .flavor, .sabzi),
        item("green_chilli", "Green chilli", .flavor, .sabzi),
        item("lemon", "Lemon", .flavor, .sabzi),
        item("curry_leaves", "Curry leaves", .flavor, .sabzi),
        item("garam_masala", "Garam masala", .flavor, .masala),
        item("kasuri_methi", "Kasuri methi", .flavor, .masala),
        item("soy_sauce", "Soy sauce", .flavor), item("coriander", "Coriander", .optional, .sabzi),
        item("cream", "Cream", .optional, .dairy), item("salt", "Salt", .staple, .masala),
        item("oil", "Oil", .staple, .oilGhee), item("haldi", "Haldi", .staple, .masala),
        item("jeera", "Jeera", .staple, .masala),
    ]

    private static func recipe(
        _ id: String, _ name: String, meals: Set<MealType> = [.lunch, .dinner], minutes: Int,
        base: DishBase, required: [String], optional: [String] = [], tags: DishTags
    ) -> Recipe {
        let lines =
            required.map { RecipeIngredient(ingredientId: $0, quantityText: "as needed") }
            + optional.map {
                RecipeIngredient(ingredientId: $0, quantityText: "to garnish", isOptional: true)
            }
        return Recipe(
            id: id, name: name, mealTypes: meals, minutes: minutes, base: base, ingredients: lines,
            steps: ["Cook it."], tags: tags, source: .seed)
    }

    private static func tags(
        _ region: Region, _ dishType: DishType, _ flavours: Set<Flavour>, _ heaviness: Heaviness,
        _ protein: Protein
    ) -> DishTags {
        DishTags(
            region: region, dishType: dishType, flavours: flavours, heaviness: heaviness,
            protein: protein)
    }

    /// The 13 fixture recipes, in the same required-ingredient order as `KyaCore`.
    static let recipes: [Recipe] = [
        recipe(
            "aloo_matar", "Aloo Matar", minutes: 30, base: .roti,
            required: ["potato", "matar", "onion", "tomato", "salt", "oil", "haldi"],
            optional: ["coriander"],
            tags: tags(.north, .curry, [.spicy, .savoury], .medium, .vegOnly)),
        recipe(
            "palak_paneer", "Palak Paneer", minutes: 35, base: .roti,
            required: ["palak", "paneer", "onion", "ginger_garlic", "kasuri_methi", "salt", "oil"],
            optional: ["cream"], tags: tags(.north, .curry, [.savoury, .mild], .medium, .paneer)),
        recipe(
            "dal_tadka", "Dal Tadka", minutes: 30, base: .none,
            required: ["toor_dal", "onion", "tomato", "jeera", "haldi", "salt", "oil"],
            optional: ["coriander"],
            tags: tags(.north, .dal, [.savoury, .spicy], .light, .dalLegume)),
        recipe(
            "jeera_rice", "Jeera Rice", minutes: 20, base: .rice,
            required: ["rice", "jeera", "oil", "salt"],
            tags: tags(.north, .rice, [.savoury, .mild], .light, .vegOnly)),
        recipe(
            "rajma_chawal", "Rajma Chawal", minutes: 60, base: .rice,
            required: [
                "rajma", "rice", "onion", "tomato", "ginger_garlic", "garam_masala", "salt", "oil",
            ],
            tags: tags(.punjabi, .curry, [.spicy, .savoury], .heavy, .dalLegume)),
        recipe(
            "chole_bhature", "Chole Bhature", minutes: 50, base: .bread,
            required: ["chana", "onion", "tomato", "ginger_garlic", "garam_masala", "salt", "oil"],
            tags: tags(.punjabi, .curry, [.spicy, .tangy], .heavy, .dalLegume)),
        recipe(
            "masala_dosa", "Masala Dosa", meals: [.breakfast, .lunch], minutes: 40, base: .none,
            required: [
                "dosa_batter", "potato", "onion", "green_chilli", "curry_leaves", "salt", "oil",
            ],
            tags: tags(.south, .breakfast, [.savoury, .spicy], .medium, .vegOnly)),
        recipe(
            "lemon_rice", "Lemon Rice", minutes: 20, base: .rice,
            required: ["rice", "lemon", "curry_leaves", "haldi", "salt", "oil"],
            tags: tags(.south, .rice, [.tangy, .savoury], .light, .vegOnly)),
        recipe(
            "poha", "Kanda Poha", meals: [.breakfast, .snack], minutes: 15, base: .none,
            required: ["poha", "onion", "green_chilli", "haldi", "salt", "oil"],
            optional: ["lemon", "coriander"],
            tags: tags(.west, .breakfast, [.savoury, .mild], .light, .vegOnly)),
        recipe(
            "upma", "Upma", meals: [.breakfast], minutes: 20, base: .none,
            required: ["rava", "onion", "green_chilli", "curry_leaves", "salt", "oil"],
            tags: tags(.south, .breakfast, [.savoury, .mild], .light, .vegOnly)),
        recipe(
            "egg_curry", "Egg Curry", minutes: 35, base: .rice,
            required: [
                "egg", "onion", "tomato", "ginger_garlic", "garam_masala", "haldi", "salt", "oil",
            ],
            tags: tags(.east, .curry, [.spicy, .savoury], .medium, .egg)),
        recipe(
            "dhokla", "Khaman Dhokla", meals: [.breakfast, .snack], minutes: 30, base: .none,
            required: ["besan", "curd", "lemon", "green_chilli", "salt", "oil"],
            tags: tags(.gujarati, .snack, [.sweet, .tangy], .light, .vegOnly)),
        recipe(
            "veg_hakka_noodles", "Veg Hakka Noodles", meals: [.dinner, .snack], minutes: 25,
            base: .none,
            required: ["noodles", "cabbage", "soy_sauce", "ginger_garlic", "oil", "salt"],
            tags: tags(.indoChinese, .onePot, [.spicy, .savoury], .medium, .vegOnly)),
    ]

    /// Pantry rows at Plenty, stocked a week before the fixed clock.
    static func stocked(_ ids: [String]) -> [PantryItem] {
        ids.map {
            PantryItem(
                ingredientId: $0, level: .plenty,
                updatedAt: weekdayDinner.addingTimeInterval(-7 * 86_400))
        }
    }

    /// A fresh in-memory store with the fixture catalog and recipes, plus `pantry`.
    static func repositories(
        pantry: [String] = k2Pantry, events: [SwipeEvent] = []
    ) async throws -> RepositorySet {
        let repositories = try SwiftDataStore.inMemory().repositories
        try await repositories.ingredients.upsert(catalog)
        try await repositories.recipes.upsert(recipes)
        try await repositories.pantry.setLevels(stocked(pantry))
        for event in events { try await repositories.swipeEvents.add(event) }
        return repositories
    }
}

/// A clock tests can move, e.g. across midnight.
@MainActor
final class DeckTestClock {
    /// The current instant.
    var now: Date

    init(_ now: Date = DeckTestFixtures.weekdayDinner) {
        self.now = now
    }
}
