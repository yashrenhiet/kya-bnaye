import Foundation
import KyaCore
import Testing

/// Fixtures mirroring `legacy/packages/kya_core/test/backup/backup_fixtures.dart`.
enum BackupFixtures {
    /// Dart `DateTime(2026, 9, 26, 19, 30, 15, 123, 456)`: local wall-clock
    /// time with sub-second precision.
    static func localTime() throws -> Date {
        try TestDates.local(2026, 9, 26, 19, 30, 15).addingTimeInterval(0.123_456)
    }

    /// Dart `DateTime.utc(2026, 3, 1, 4, 5, 6, 789, 12)`.
    static func utcTime() throws -> Date {
        try TestDates.local(2026, 3, 1, 4, 5, 6, calendar: TestDates.utcCalendar)
            .addingTimeInterval(0.789_012)
    }

    /// Dart `DateTime.utc(2026, 9, 26, 12)`.
    static func exportedAt() throws -> Date { try TestDates.utc(2026, 9, 26, 12) }

    static let seedIngredient = Ingredient(
        id: "potato", name: "Potato", aliases: ["aloo", "batata"], category: .sabzi, role: .core,
        buyFrom: .sabziwala, shelfLifeDays: 14)

    static let bareIngredient = Ingredient(
        id: "salt", name: "Salt", category: .masala, role: .staple, buyFrom: .kirana)

    static let userIngredient = Ingredient(
        id: "user_dragonfruit", name: "Dragonfruit", aliases: ["pitaya"], category: .fruit,
        role: .optional, buyFrom: .other, shelfLifeDays: 4, isUserCreated: true)

    static let fullRecipe = Recipe(
        id: "palak_paneer",
        name: "Palak Paneer",
        mealTypes: [.lunch, .dinner],
        minutes: 35,
        base: .roti,
        ingredients: [
            RecipeIngredient(ingredientId: "paneer", quantityText: "200 g"),
            RecipeIngredient(ingredientId: "cream", quantityText: "1 tbsp", isOptional: true),
        ],
        steps: ["Blanch palak", "Blend", "Add paneer"],
        tags: DishTags(
            region: .punjabi, dishType: .curry, flavours: [.savoury, .mild], heaviness: .heavy,
            protein: .paneer),
        source: .user,
        imageAsset: "assets/recipes/palak_paneer.webp",
        isFavorite: true,
        isHidden: true
    )

    static let bareRecipe = Recipe(
        id: "plain_rice",
        name: "Plain Rice",
        mealTypes: [],
        minutes: 0,
        base: .none,
        ingredients: [],
        steps: [],
        tags: DishTags(
            region: .indoChinese, dishType: .onePot, flavours: [], heaviness: .light,
            protein: .vegOnly),
        source: .seed
    )

    /// A bundle exercising every entity type and every nullable field in both
    /// its `nil` and non-`nil` state.
    static func fullBundle() throws -> BackupBundle {
        let local = try localTime()
        let utc = try utcTime()
        return BackupBundle(
            seedVersion: 4,
            ingredients: [seedIngredient, bareIngredient, userIngredient],
            pantryItems: [
                PantryItem(
                    ingredientId: "potato", level: .plenty, updatedAt: local,
                    expiresOn: try TestDates.local(2026, 10, 10), expiryIsEstimated: true),
                PantryItem(ingredientId: "salt", level: .low, updatedAt: utc),
                PantryItem(
                    ingredientId: "user_dragonfruit", level: .out, updatedAt: local, expiresOn: utc),
            ],
            recipes: [fullRecipe, bareRecipe],
            mealLogs: [
                MealLog(id: "m1", recipeId: "palak_paneer", mealType: .dinner, cookedAt: local),
                MealLog(id: "m2", recipeId: "plain_rice", mealType: .breakfast, cookedAt: utc),
            ],
            swipeEvents: [
                SwipeEvent(
                    id: "e1", recipeId: "palak_paneer", action: .right, mode: .kitchen, at: local,
                    deckSeed: 42),
                SwipeEvent(
                    id: "e2", recipeId: "palak_paneer", action: .undo, mode: .craving, at: utc,
                    deckSeed: -7, undoesEventId: "e1"),
                SwipeEvent(
                    id: "e3", recipeId: "plain_rice", action: .neverShow, mode: .craving,
                    at: local, deckSeed: 0),
                SwipeEvent(
                    id: "e4", recipeId: "plain_rice", action: .left, mode: .kitchen, at: local,
                    deckSeed: 1),
            ],
            shoppingItems: [
                try ShoppingItem(
                    id: "s1", ingredientId: "potato", reason: .low, isChecked: false,
                    createdAt: local),
                try ShoppingItem(
                    id: "s2", ingredientId: "paneer", reason: .recipe, recipeId: "palak_paneer",
                    isChecked: true, createdAt: utc),
                try ShoppingItem(
                    id: "s3", customName: "Birthday candles", reason: .manual, isChecked: false,
                    createdAt: local),
                try ShoppingItem(
                    id: "s4", ingredientId: "salt", reason: .out, isChecked: false,
                    createdAt: local),
            ]
        )
    }

    /// A valid backup as it looks after being read back from a file.
    static func validJSON(_ codec: BackupCodec = BackupCodec()) throws -> [String: Any] {
        try JSONText.object(try codec.encode(try fullBundle(), exportedAt: try exportedAt()))
    }

    /// `Ingredient` and `Recipe` equality is id-only, so round-trip checks
    /// compare every field explicitly; the other entities have full value
    /// equality (every `Date` compared to the exact instant).
    static func expectEqual(
        _ actual: BackupBundle, _ want: BackupBundle,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(actual.seedVersion == want.seedVersion, sourceLocation: sourceLocation)
        #expect(actual.ingredients.count == want.ingredients.count, sourceLocation: sourceLocation)
        for (lhs, rhs) in zip(actual.ingredients, want.ingredients) {
            #expect(lhs.isIdentical(to: rhs), "\(lhs) differs", sourceLocation: sourceLocation)
        }
        #expect(actual.recipes.count == want.recipes.count, sourceLocation: sourceLocation)
        for (lhs, rhs) in zip(actual.recipes, want.recipes) {
            #expect(lhs.isIdentical(to: rhs), "\(lhs) differs", sourceLocation: sourceLocation)
        }
        #expect(actual.pantryItems == want.pantryItems, sourceLocation: sourceLocation)
        #expect(actual.mealLogs == want.mealLogs, sourceLocation: sourceLocation)
        #expect(actual.swipeEvents == want.swipeEvents, sourceLocation: sourceLocation)
        #expect(actual.shoppingItems == want.shoppingItems, sourceLocation: sourceLocation)
    }

    /// The error `codec` throws for `json`, or `nil` if it decodes.
    static func decodeError(
        _ json: Any, codec: BackupCodec = BackupCodec()
    ) -> BackupFormatError? {
        do {
            _ = try codec.decode(jsonObject: json)
            return nil
        } catch {
            return error
        }
    }
}
