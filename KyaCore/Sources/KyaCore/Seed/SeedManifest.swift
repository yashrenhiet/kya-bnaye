/// The parsed `seed/manifest.json`: which fragment files make up the bundled
/// seed data, and its version.
///
/// Fragment paths are relative to `seed/` and listed in load order. Produced
/// by ``SeedCodec/decodeManifest(jsonObject:)``, which guarantees every path
/// is a safe, unique, relative, lowercase `.json` path.
public struct SeedManifest: Sendable, Hashable {
    /// Version of the bundled seed content (`AGENTS.md` section 5.6). Bumped
    /// whenever seed rows change, so first-run seeding can add new rows
    /// without clobbering user edits. Always at least 1.
    public let seedVersion: Int

    /// Fragment files holding `{"ingredients": [...]}`, in load order.
    public let ingredientFiles: [String]

    /// Fragment files holding `{"recipes": [...]}`, in load order.
    public let recipeFiles: [String]

    /// Creates a manifest. No checks are made; use ``SeedCodec`` to read one
    /// from JSON.
    ///
    /// - Parameters:
    ///   - seedVersion: Version of the seed content.
    ///   - ingredientFiles: Ingredient fragment paths.
    ///   - recipeFiles: Recipe fragment paths.
    public init(seedVersion: Int, ingredientFiles: [String], recipeFiles: [String]) {
        self.seedVersion = seedVersion
        self.ingredientFiles = ingredientFiles
        self.recipeFiles = recipeFiles
    }

    /// Every fragment path, ingredients first.
    public var allFiles: [String] { ingredientFiles + recipeFiles }
}

/// The complete bundled seed catalogue, decoded from a ``SeedManifest`` and
/// its fragments by ``SeedCodec``.
///
/// When produced by ``SeedCodec``, every recipe has
/// ``RecipeSource/seed`` as its source, every ingredient has
/// `isUserCreated == false`, and ids are unique within each list — but no
/// cross-reference or content rule has been checked yet: run
/// ``SeedValidator`` for that.
public struct SeedBundle: Sendable {
    /// Copied from ``SeedManifest/seedVersion``.
    public let seedVersion: Int

    /// Catalogue ingredients, in manifest fragment order.
    public let ingredients: [Ingredient]

    /// Seed recipes, in manifest fragment order.
    public let recipes: [Recipe]

    /// Creates a bundle (e.g. a test fixture). No checks are made.
    ///
    /// - Parameters:
    ///   - seedVersion: Version of the seed content.
    ///   - ingredients: Catalogue ingredients.
    ///   - recipes: Seed recipes.
    public init(seedVersion: Int, ingredients: [Ingredient], recipes: [Recipe]) {
        self.seedVersion = seedVersion
        self.ingredients = ingredients
        self.recipes = recipes
    }
}
