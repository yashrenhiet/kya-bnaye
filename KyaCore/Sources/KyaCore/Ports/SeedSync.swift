import Foundation

/// What one ``SeedSync/apply(ingredients:recipes:version:)`` call did.
public enum SeedSyncOutcome: Sendable, Equatable {
    /// The stored seed version is already `storedVersion`, which is at least
    /// the offered version. Nothing was written.
    case upToDate(storedVersion: Int)

    /// The offered seed was applied.
    case applied(SeedSyncReport)
}

/// The details of an applied seed.
public struct SeedSyncReport: Sendable, Equatable {
    /// The seed version stored before this run (`nil` on first run).
    public let previousVersion: Int?

    /// The seed version stored after this run.
    public let appliedVersion: Int

    /// Ingredient ids that were missing and have been inserted, ascending.
    public let insertedIngredientIds: [String]

    /// Recipe ids that were missing and have been inserted, ascending.
    public let insertedRecipeIds: [String]

    /// Creates a report.
    ///
    /// - Parameters:
    ///   - previousVersion: The seed version stored before the run.
    ///   - appliedVersion: The seed version stored after the run.
    ///   - insertedIngredientIds: Inserted ingredient ids, ascending.
    ///   - insertedRecipeIds: Inserted recipe ids, ascending.
    public init(
        previousVersion: Int?,
        appliedVersion: Int,
        insertedIngredientIds: [String],
        insertedRecipeIds: [String]
    ) {
        self.previousVersion = previousVersion
        self.appliedVersion = appliedVersion
        self.insertedIngredientIds = insertedIngredientIds
        self.insertedRecipeIds = insertedRecipeIds
    }
}

/// First-run seeding and later seed upgrades (`AGENTS.md` section 5.6): loads
/// the bundled seed rows into the repositories **without ever overwriting an
/// existing row**, so user edits, favourites and hidden flags survive a seed
/// update.
///
/// Rules:
/// - Runs only when no seed version is stored or the stored one is lower than
///   the offered one; otherwise it is a no-op (a downgrade never lowers the
///   stored version).
/// - Inserts ingredients first, then recipes (recipes reference ingredients),
///   and records the version last. A crash in between leaves the old version
///   stored, so the next launch re-runs it; every step is idempotent.
/// - A seed row the user deleted is inserted again on the next version bump
///   (the repositories keep no tombstones).
///
/// Validating the seed (unique ids, referential integrity) is the seed
/// codec/validator's job and happens before this.
public struct SeedSync: Sendable {
    private let ingredientRepository: any IngredientRepository
    private let recipeRepository: any RecipeRepository
    private let seedStateRepository: any SeedStateRepository

    /// Creates the use case over the repositories it writes.
    ///
    /// - Parameters:
    ///   - ingredients: Receives missing seed ingredients.
    ///   - recipes: Receives missing seed recipes.
    ///   - seedState: Holds the applied seed version.
    public init(
        ingredients: any IngredientRepository,
        recipes: any RecipeRepository,
        seedState: any SeedStateRepository
    ) {
        ingredientRepository = ingredients
        recipeRepository = recipes
        seedStateRepository = seedState
    }

    /// Applies a seed if it is newer than the stored one.
    ///
    /// Postconditions on success: every offered id exists in its repository;
    /// every row that existed before is unchanged; the stored version is
    /// `max(stored, version)`.
    ///
    /// - Parameters:
    ///   - ingredients: The bundled catalog.
    ///   - recipes: The bundled recipes.
    ///   - version: The bundle's `seedVersion`.
    /// - Returns: What was done.
    /// - Throws: Any repository error; the stored version is then unchanged
    ///   and a later call completes the sync.
    public func apply(
        ingredients: [Ingredient],
        recipes: [Recipe],
        version: Int
    ) async throws -> SeedSyncOutcome {
        let stored = try await seedStateRepository.seedVersion()
        if let stored, stored >= version {
            return .upToDate(storedVersion: stored)
        }
        let insertedIngredients = try await ingredientRepository.insertMissing(ingredients)
        let insertedRecipes = try await recipeRepository.insertMissing(recipes)
        try await seedStateRepository.setSeedVersion(version)
        return .applied(
            SeedSyncReport(
                previousVersion: stored,
                appliedVersion: version,
                insertedIngredientIds: insertedIngredients,
                insertedRecipeIds: insertedRecipes
            ))
    }

    /// Applies a decoded and validated seed bundle if it is newer than the
    /// stored one; same rules as ``apply(ingredients:recipes:version:)``.
    ///
    /// - Parameter bundle: The bundled seed.
    /// - Returns: What was done.
    /// - Throws: Any repository error; the stored version is then unchanged.
    public func apply(_ bundle: SeedBundle) async throws -> SeedSyncOutcome {
        try await apply(
            ingredients: bundle.ingredients, recipes: bundle.recipes, version: bundle.seedVersion)
    }
}
