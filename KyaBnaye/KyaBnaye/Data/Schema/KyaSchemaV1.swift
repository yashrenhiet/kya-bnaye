import Foundation
import SwiftData

// Storage shape (M3). Every `@Model` here is internal to `Data/` and maps to a `KyaCore`
// value type at the adapter boundary (`RecordMapping.swift`); none crosses a port.
//
// Enums are stored as their `String` raw values (the same names as the seed/backup JSON),
// not as the `KyaCore` enums themselves, so an unknown value read from disk (e.g. written by
// a newer build) surfaces as a typed `DataStoreError.corruptRecord` instead of a crash
// inside SwiftData's decoder, and the schema never depends on `KyaCore`'s Codable details.
//
// Recipe aggregate, options weighed:
// 1. Relationships: `RecipeIngredientRecord`/`StepRecord` child models with a cascade
//    inverse. Queryable in SQL ("recipes using paneer"), but SwiftData does not keep
//    to-many order (an explicit position column is needed), a full-field `upsert` has to
//    diff or delete-and-reinsert children, and every read joins. No port queries inside a
//    recipe: the recommender ranks the whole book in memory (~80-200 recipes).
// 2. Value columns (chosen): the recipe is one row. Tag dimensions are scalar raw-value
//    columns (queryable later), `mealTypes`/`flavours`/`steps` are `[String]` columns, and
//    the ordered ingredient lines are one JSON `Data` column (`StoredRecipeLine`), encoded
//    by us so its format is explicit and versionable. A recipe is always read and written
//    whole, so upsert is a plain field copy with no orphaned children, and backup restore
//    is trivially atomic.
// Trade-off accepted: no SQL predicate over ingredient lines; if one is ever needed, a
// later schema version adds a derived child table in a planned migration stage.
//
// Uniqueness uses `@Attribute(.unique)`, not `#Unique` (iOS 18+; the app targets iOS 17).
// The adapters never rely on SwiftData's implicit upsert-on-conflict: they look rows up
// first, so append-only logs can reject duplicate ids.

/// Version 1 of the persisted schema. Future versions add a `KyaSchemaV2` and a migration
/// stage in ``KyaMigrationPlan``; this enum is then frozen.
enum KyaSchemaV1: VersionedSchema {
    /// Semantic version of this schema.
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    /// Every model in this version.
    static var models: [any PersistentModel.Type] {
        [
            IngredientRecord.self, PantryRecord.self, RecipeRecord.self, MealLogRecord.self,
            SwipeEventRecord.self, ShoppingItemRecord.self, SeedStateRecord.self,
        ]
    }

    /// One catalog ingredient (``KyaCore/Ingredient``).
    @Model
    final class IngredientRecord {
        /// Canonical ingredient id; unique.
        @Attribute(.unique) var id: String
        /// Display name.
        var name: String
        /// Alternative names, in stored order.
        var aliases: [String]
        /// ``KyaCore/IngredientCategory`` raw value.
        var categoryRaw: String
        /// ``KyaCore/IngredientRole`` raw value.
        var roleRaw: String
        /// ``KyaCore/BuyFrom`` raw value.
        var buyFromRaw: String
        /// Typical shelf life in days, if it expires.
        var shelfLifeDays: Int?
        /// Whether the user created it.
        var isUserCreated: Bool

        /// Creates an empty record for `id`; the mapper fills in the fields.
        init(id: String) {
            self.id = id
            name = ""
            aliases = []
            categoryRaw = ""
            roleRaw = ""
            buyFromRaw = ""
            shelfLifeDays = nil
            isUserCreated = false
        }
    }

    /// One pantry stock record (``KyaCore/PantryItem``), keyed on the ingredient id.
    @Model
    final class PantryRecord {
        /// The ingredient this record belongs to; unique (one record per ingredient).
        @Attribute(.unique) var ingredientId: String
        /// ``KyaCore/StockLevel`` raw value.
        var levelRaw: String
        /// Known or estimated expiry.
        var expiresOn: Date?
        /// Whether `expiresOn` is an estimate.
        var expiryIsEstimated: Bool
        /// When the record was last changed.
        var updatedAt: Date

        /// Creates an empty record for `ingredientId`; the mapper fills in the fields.
        init(ingredientId: String) {
            self.ingredientId = ingredientId
            levelRaw = ""
            expiresOn = nil
            expiryIsEstimated = false
            updatedAt = .distantPast
        }
    }

    /// One recipe (``KyaCore/Recipe``) stored as a single row; see the file comment.
    @Model
    final class RecipeRecord {
        /// Canonical recipe id; unique.
        @Attribute(.unique) var id: String
        /// Display name.
        var name: String
        /// ``KyaCore/MealType`` raw values, sorted.
        var mealTypesRaw: [String]
        /// Typical cooking time.
        var minutes: Int
        /// ``KyaCore/DishBase`` raw value.
        var baseRaw: String
        /// JSON-encoded `[StoredRecipeLine]`, in display order.
        var ingredientLines: Data
        /// Cooking steps, in order.
        var steps: [String]
        /// ``KyaCore/Region`` raw value.
        var regionRaw: String
        /// ``KyaCore/DishType`` raw value.
        var dishTypeRaw: String
        /// ``KyaCore/Flavour`` raw values, sorted.
        var flavoursRaw: [String]
        /// ``KyaCore/Heaviness`` raw value.
        var heavinessRaw: String
        /// ``KyaCore/Protein`` raw value.
        var proteinRaw: String
        /// Bundled image path, if any.
        var imageAsset: String?
        /// Whether the user favourited it.
        var isFavorite: Bool
        /// Whether the user chose "Never show".
        var isHidden: Bool
        /// ``KyaCore/RecipeSource`` raw value.
        var sourceRaw: String

        /// Creates an empty record for `id`; the mapper fills in the fields.
        init(id: String) {
            self.id = id
            name = ""
            mealTypesRaw = []
            minutes = 0
            baseRaw = ""
            ingredientLines = Data()
            steps = []
            regionRaw = ""
            dishTypeRaw = ""
            flavoursRaw = []
            heavinessRaw = ""
            proteinRaw = ""
            imageAsset = nil
            isFavorite = false
            isHidden = false
            sourceRaw = ""
        }
    }

    /// One "I made this" entry (``KyaCore/MealLog``); append-only.
    @Model
    final class MealLogRecord {
        /// Log id; unique.
        @Attribute(.unique) var id: String
        /// The cooked recipe.
        var recipeId: String
        /// ``KyaCore/MealType`` raw value.
        var mealTypeRaw: String
        /// When it was cooked.
        var cookedAt: Date

        /// Creates an empty record for `id`; the mapper fills in the fields.
        init(id: String) {
            self.id = id
            recipeId = ""
            mealTypeRaw = ""
            cookedAt = .distantPast
        }
    }

    /// One swipe (``KyaCore/SwipeEvent``); append-only (ADR 008).
    @Model
    final class SwipeEventRecord {
        /// Event id; unique.
        @Attribute(.unique) var id: String
        /// The recipe the card showed.
        var recipeId: String
        /// ``KyaCore/SwipeAction`` raw value.
        var actionRaw: String
        /// ``KyaCore/SwipeMode`` raw value.
        var modeRaw: String
        /// When the swipe happened.
        var at: Date
        /// The seed the deck was built with.
        var deckSeed: Int
        /// For undo events, the reverted event's id.
        var undoesEventId: String?

        /// Creates an empty record for `id`; the mapper fills in the fields.
        init(id: String) {
            self.id = id
            recipeId = ""
            actionRaw = ""
            modeRaw = ""
            at = .distantPast
            deckSeed = 0
            undoesEventId = nil
        }
    }

    /// One shopping-list line (``KyaCore/ShoppingItem``).
    @Model
    final class ShoppingItemRecord {
        /// Item id; unique.
        @Attribute(.unique) var id: String
        /// List position: first-insertion order, kept when the item is replaced.
        var position: Int
        /// Catalog ingredient id, if catalog-backed.
        var ingredientId: String?
        /// Free-typed name, if not catalog-backed.
        var customName: String?
        /// ``KyaCore/ShoppingReason`` raw value.
        var reasonRaw: String
        /// The recipe that asked for it, if any.
        var recipeId: String?
        /// Whether it is ticked off.
        var isChecked: Bool
        /// When it was added.
        var createdAt: Date

        /// Creates an empty record for `id` at `position`; the mapper fills in the fields.
        init(id: String, position: Int) {
            self.id = id
            self.position = position
            ingredientId = nil
            customName = nil
            reasonRaw = ""
            recipeId = nil
            isChecked = false
            createdAt = .distantPast
        }
    }

    /// Single-row key/value table holding the applied seed version.
    @Model
    final class SeedStateRecord {
        /// The row key; unique. Only ``SeedStateRecord/seedVersionKey`` is used.
        @Attribute(.unique) var key: String
        /// The last fully applied seed version.
        var version: Int

        /// The key of the seed-version row.
        static let seedVersionKey = "seedVersion"

        /// Creates the row.
        init(key: String, version: Int) {
            self.key = key
            self.version = version
        }
    }
}
