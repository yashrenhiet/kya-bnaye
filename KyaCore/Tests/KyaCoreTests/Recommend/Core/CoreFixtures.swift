import Foundation
import KyaCore

/// Builders for the recommender core unit tests, mirroring
/// `legacy/packages/kya_core/test/recommend/core/fixtures.dart`.
///
/// Every builder takes only the fields a test cares about and fills the rest
/// with neutral defaults. Dates are local wall time in `Calendar.kyaDefault`,
/// like Dart's `DateTime(y, m, d, h)`, so the suite behaves the same under any
/// `TZ`.
enum CoreFixtures {
    /// Tolerance used by the Dart tests' `closeTo`.
    static let eps = 1e-9

    /// Dart `closeTo(expected, eps)`: `false` for a `nil` value.
    static func near(_ value: Double?, _ expected: Double, eps: Double = eps) -> Bool {
        guard let value else { return false }
        return abs(value - expected) <= eps
    }

    /// Local wall-clock time; `.distantPast` only if the calendar rejects it.
    static func wall(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0)
        -> Date
    {
        let parts = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        return Calendar.kyaDefault.date(from: parts) ?? .distantPast
    }

    /// Dart `DateTime(2026, 9, 26, 12)`: a fixed, DST-free reference instant.
    static var refNow: Date { wall(2026, 9, 26, 12) }

    /// `refNow` minus `days` calendar days, at `hour`:`minute` local time.
    static func daysAgo(_ days: Int, hour: Int = 12, minute: Int = 0) -> Date {
        let base = wall(2026, 9, 26, hour, minute)
        return Calendar.kyaDefault.date(byAdding: .day, value: -days, to: base) ?? .distantPast
    }

    /// Exact elapsed-time offset before `refNow`.
    static func ago(days: Double = 0, hours: Double = 0) -> Date {
        refNow.addingTimeInterval(-(days * 86_400 + hours * 3_600))
    }

    /// Exact elapsed-time offset after `refNow`.
    static func later(days: Double = 0, hours: Double = 0) -> Date {
        refNow.addingTimeInterval(days * 86_400 + hours * 3_600)
    }

    static let defaultTags = DishTags(
        region: .north, dishType: .curry, flavours: [.spicy], heaviness: .heavy, protein: .paneer)

    static let otherTags = DishTags(
        region: .south, dishType: .breakfast, flavours: [.tangy, .mild], heaviness: .light,
        protein: .dalLegume)

    /// Every tag key carried by ``defaultTags``.
    static var defaultKeys: [TagKey] { defaultTags.allKeys }

    static func recipe(
        _ id: String,
        tags: DishTags = defaultTags,
        mealTypes: Set<MealType> = [.lunch, .dinner],
        base: DishBase = .roti,
        ingredients: [RecipeIngredient] = [],
        isHidden: Bool = false,
        isFavorite: Bool = false,
        minutes: Int = 25
    ) -> Recipe {
        Recipe(
            id: id, name: "Recipe \(id)", mealTypes: mealTypes, minutes: minutes, base: base,
            ingredients: ingredients, steps: ["Cook"], tags: tags, source: .seed,
            isFavorite: isFavorite, isHidden: isHidden)
    }

    static func uses(_ ingredientId: String, optional: Bool = false) -> RecipeIngredient {
        RecipeIngredient(ingredientId: ingredientId, quantityText: "1", isOptional: optional)
    }

    static func ingredient(_ id: String, _ role: IngredientRole) -> Ingredient {
        Ingredient(id: id, name: id, category: .other, role: role, buyFrom: .kirana)
    }

    static func stock(_ ingredientId: String, _ level: StockLevel) -> PantryItem {
        PantryItem(ingredientId: ingredientId, level: level, updatedAt: refNow)
    }

    static func swipe(
        _ id: String,
        _ recipeId: String,
        _ action: SwipeAction,
        _ at: Date,
        undoes: String? = nil
    ) -> SwipeEvent {
        SwipeEvent(
            id: id, recipeId: recipeId, action: action, mode: .craving, at: at, deckSeed: 7,
            undoesEventId: undoes)
    }

    static func undo(_ id: String, _ undoes: String, _ at: Date) -> SwipeEvent {
        swipe(id, "n/a", .undo, at, undoes: undoes)
    }

    static func cooked(_ id: String, _ recipeId: String, _ at: Date) -> MealLog {
        MealLog(id: id, recipeId: recipeId, mealType: .dinner, cookedAt: at)
    }
}
