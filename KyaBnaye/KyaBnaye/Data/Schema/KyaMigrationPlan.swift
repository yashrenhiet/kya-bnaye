import SwiftData

/// The ordered history of persisted schemas and how to migrate between them.
///
/// Planned from day one so the first schema change is a new `VersionedSchema` plus one
/// `MigrationStage` here, never an ad-hoc fix. Rules for adding a version:
/// - Copy the models into `KyaSchemaV<n+1>` and leave every earlier version frozen.
/// - Append the schema to ``schemas`` and a stage to ``stages``; prefer
///   `.lightweight(fromVersion:toVersion:)` and use `.custom` only when data must be
///   transformed (e.g. re-encoding `RecipeRecord.ingredientLines`).
/// - Point ``CurrentSchema`` at the new version and add a migration test that opens a
///   store written by the previous version.
///
/// A migration failure never crashes the app: ``SwiftDataStore`` reports it as
/// ``DataStoreError/storeUnavailable(reason:)`` and the launch screen offers recovery.
enum KyaMigrationPlan: SchemaMigrationPlan {
    /// Every schema version, oldest first.
    static var schemas: [any VersionedSchema.Type] { [KyaSchemaV1.self] }

    /// Migration stages between consecutive versions; none yet (v1 is the first).
    static var stages: [MigrationStage] { [] }
}

/// The schema version the app reads and writes.
typealias CurrentSchema = KyaSchemaV1

/// Current ingredient model.
typealias IngredientRecord = CurrentSchema.IngredientRecord
/// Current pantry model.
typealias PantryRecord = CurrentSchema.PantryRecord
/// Current recipe model.
typealias RecipeRecord = CurrentSchema.RecipeRecord
/// Current meal-log model.
typealias MealLogRecord = CurrentSchema.MealLogRecord
/// Current swipe-event model.
typealias SwipeEventRecord = CurrentSchema.SwipeEventRecord
/// Current shopping-item model.
typealias ShoppingItemRecord = CurrentSchema.ShoppingItemRecord
/// Current seed-state model.
typealias SeedStateRecord = CurrentSchema.SeedStateRecord
