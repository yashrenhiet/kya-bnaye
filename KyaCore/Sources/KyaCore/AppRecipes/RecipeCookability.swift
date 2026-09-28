/// How one recipe line stands against the pantry, for the recipe detail's
/// have/missing marks.
public enum RecipeLineStatus: String, Sendable, CaseIterable {
    /// In stock (`plenty` or `low`).
    case have
    /// Counts as missing: not stocked, or marked out.
    case missing
    /// A staple with no stock record, assumed present (salt, oil...).
    case assumedStaple
    /// An optional line or optional-role ingredient; never counts as missing.
    case optional
}

/// One recipe line with its catalog entry and pantry status.
public struct RecipeLineAvailability: Sendable, Hashable {
    /// The recipe line.
    public let line: RecipeIngredient
    /// The catalog entry, or `nil` if the id is not in the catalog.
    public let ingredient: Ingredient?
    /// The line's status.
    public let status: RecipeLineStatus

    /// Creates a line status.
    ///
    /// - Parameters:
    ///   - line: The recipe line.
    ///   - ingredient: Its catalog entry, if known.
    ///   - status: Its status.
    public init(line: RecipeIngredient, ingredient: Ingredient?, status: RecipeLineStatus) {
        self.line = line
        self.ingredient = ingredient
        self.status = status
    }
}

/// Whether a recipe can be cooked with what is at home, line by line.
///
/// Built on ``IngredientAvailability`` (the single "is it available" rule), so
/// a line is ``RecipeLineStatus/missing`` exactly when that rule says it is not
/// available: staples are assumed unless marked out, optional lines and
/// optional-role ingredients never count.
public struct RecipeCookability: Sendable, Hashable {
    /// Every line in recipe order.
    public let lines: [RecipeLineAvailability]

    /// Creates a result from precomputed lines.
    ///
    /// - Parameter lines: The lines in recipe order.
    public init(lines: [RecipeLineAvailability]) {
        self.lines = lines
    }

    /// Ids of the missing ingredients, in recipe order, each listed once.
    public var missingIngredientIds: [String] {
        var seen = Set<String>()
        return lines.lazy.filter { $0.status == .missing }.map(\.line.ingredientId)
            .filter { seen.insert($0).inserted }
    }

    /// How many distinct ingredients are missing.
    public var missingCount: Int { missingIngredientIds.count }

    /// `true` when nothing is missing ("ready").
    public var isReady: Bool { !lines.contains { $0.status == .missing } }

    /// Evaluates `recipe` against the pantry.
    ///
    /// - Parameters:
    ///   - recipe: The recipe to check.
    ///   - ingredientsById: The catalog, keyed by id.
    ///   - pantry: Pantry records keyed by ingredient id.
    /// - Returns: The per-line result.
    public static func evaluate(
        _ recipe: Recipe,
        ingredientsById: [String: Ingredient],
        pantry: [String: PantryItem]
    ) -> RecipeCookability {
        RecipeCookability(
            lines: recipe.ingredients.map { line in
                let ingredient = ingredientsById[line.ingredientId]
                return RecipeLineAvailability(
                    line: line, ingredient: ingredient,
                    status: status(of: line, role: ingredient?.role, pantry: pantry))
            })
    }

    private static func status(
        of line: RecipeIngredient, role: IngredientRole?, pantry: [String: PantryItem]
    ) -> RecipeLineStatus {
        if line.isOptional || role == .optional { return .optional }
        guard IngredientAvailability.isAvailable(line, role: role, pantry: pantry) else {
            return .missing
        }
        return role == .staple && pantry[line.ingredientId] == nil ? .assumedStaple : .have
    }
}
