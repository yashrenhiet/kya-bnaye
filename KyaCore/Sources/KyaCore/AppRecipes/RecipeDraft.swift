/// A problem that keeps a ``RecipeDraft`` from being saved. Mirrors the seed
/// recipe rules where they make sense for a hand-entered recipe.
public enum RecipeDraftIssue: Sendable, Hashable {
    /// The name is blank.
    case blankName
    /// Another recipe already uses this name (compared like ingredient names).
    case duplicateName
    /// No meal slot is selected.
    case noMealTypes
    /// Minutes are outside ``RecipeDraft/minutesRange``.
    case minutesOutOfRange
    /// No non-blank step.
    case noSteps
    /// No ingredient lines.
    case noIngredients
    /// A line names an id that is not in the catalog.
    case unknownIngredient(String)
    /// The same ingredient appears on more than one line.
    case repeatedIngredient(String)
    /// No required line has the core role, so the recipe could never be
    /// judged "missing" anything that matters.
    case noCoreIngredient
    /// No flavour is selected.
    case noFlavours
    /// Mild and spicy are both selected.
    case mildAndSpicy
    /// A rice dish without a rice base, or a bread without a roti/bread base.
    case baseMismatch

    /// A short, user-facing explanation.
    public var message: String {
        switch self {
        case .blankName: "Give the dish a name."
        case .duplicateName: "Another recipe already has this name."
        case .noMealTypes: "Pick at least one meal."
        case .minutesOutOfRange:
            "Cooking time must be \(RecipeDraft.minutesRange.lowerBound)–"
                + "\(RecipeDraft.minutesRange.upperBound) minutes."
        case .noSteps: "Add at least one step."
        case .noIngredients: "Add at least one ingredient."
        case .unknownIngredient(let id): "“\(id)” isn't in the ingredient list."
        case .repeatedIngredient(let id): "“\(id)” is listed more than once."
        case .noCoreIngredient: "At least one required ingredient must be a main ingredient."
        case .noFlavours: "Pick at least one flavour."
        case .mildAndSpicy: "A dish can't be both mild and spicy."
        case .baseMismatch: "Rice dishes need a rice base; breads need roti or bread."
        }
    }
}

/// The editable form of a ``Recipe`` behind Add/Edit recipe.
public struct RecipeDraft: Sendable, Hashable {
    /// Allowed cooking time, in minutes (the seed rule).
    public static let minutesRange = SeedRecipeRules.minutes

    /// Display name; trimmed when building.
    public var name: String
    /// Meal slots.
    public var mealTypes: Set<MealType>
    /// Cooking time in minutes.
    public var minutes: Int
    /// Starch base.
    public var base: DishBase
    /// Ingredient lines in display order.
    public var ingredients: [RecipeIngredient]
    /// Steps; blank ones are dropped when building.
    public var steps: [String]
    /// Regional cuisine.
    public var region: Region
    /// Kind of dish.
    public var dishType: DishType
    /// Flavour notes.
    public var flavours: Set<Flavour>
    /// How filling the dish is.
    public var heaviness: Heaviness
    /// Main protein.
    public var protein: Protein

    /// Creates a draft. The defaults describe an empty new recipe.
    ///
    /// - Parameters:
    ///   - name: Defaults to empty.
    ///   - mealTypes: Defaults to none.
    ///   - minutes: Defaults to 20.
    ///   - base: Defaults to ``DishBase/none``.
    ///   - ingredients: Defaults to none.
    ///   - steps: Defaults to one blank step, ready to type into.
    ///   - region: Defaults to ``Region/north``.
    ///   - dishType: Defaults to ``DishType/curry``.
    ///   - flavours: Defaults to savoury.
    ///   - heaviness: Defaults to ``Heaviness/medium``.
    ///   - protein: Defaults to ``Protein/vegOnly``.
    public init(
        name: String = "",
        mealTypes: Set<MealType> = [],
        minutes: Int = 20,
        base: DishBase = .none,
        ingredients: [RecipeIngredient] = [],
        steps: [String] = [""],
        region: Region = .north,
        dishType: DishType = .curry,
        flavours: Set<Flavour> = [.savoury],
        heaviness: Heaviness = .medium,
        protein: Protein = .vegOnly
    ) {
        self.name = name
        self.mealTypes = mealTypes
        self.minutes = minutes
        self.base = base
        self.ingredients = ingredients
        self.steps = steps
        self.region = region
        self.dishType = dishType
        self.flavours = flavours
        self.heaviness = heaviness
        self.protein = protein
    }

    /// A draft holding every editable field of `recipe`.
    ///
    /// - Parameter recipe: The recipe to edit.
    public init(recipe: Recipe) {
        self.init(
            name: recipe.name, mealTypes: recipe.mealTypes, minutes: recipe.minutes,
            base: recipe.base, ingredients: recipe.ingredients, steps: recipe.steps,
            region: recipe.tags.region, dishType: recipe.tags.dishType,
            flavours: recipe.tags.flavours, heaviness: recipe.tags.heaviness,
            protein: recipe.tags.protein)
    }

    /// Every issue that blocks saving, in form order; empty means valid.
    ///
    /// - Parameters:
    ///   - ingredientsById: The catalog, keyed by id.
    ///   - existingRecipes: The recipe book, for the duplicate-name check.
    ///   - editingId: The id of the recipe being edited (excluded from the
    ///     duplicate-name check), or `nil` for a new recipe.
    /// - Returns: The issues.
    public func validate(
        ingredientsById: [String: Ingredient],
        existingRecipes: [Recipe],
        editingId: String?
    ) -> [RecipeDraftIssue] {
        var issues: [RecipeDraftIssue] = []
        let key = IngredientNormalizer.normalise(name)
        if key.isEmpty {
            issues.append(.blankName)
        } else if existingRecipes.contains(where: {
            $0.id != editingId && IngredientNormalizer.normalise($0.name) == key
        }) {
            issues.append(.duplicateName)
        }
        if mealTypes.isEmpty { issues.append(.noMealTypes) }
        if !Self.minutesRange.contains(minutes) { issues.append(.minutesOutOfRange) }
        if trimmedSteps.isEmpty { issues.append(.noSteps) }
        issues += ingredientIssues(ingredientsById)
        if flavours.isEmpty {
            issues.append(.noFlavours)
        } else if flavours.isSuperset(of: [.mild, .spicy]) {
            issues.append(.mildAndSpicy)
        }
        if !isBaseAllowed { issues.append(.baseMismatch) }
        return issues
    }

    /// Builds the recipe to save. Trims the name, step and quantity text and
    /// drops blank steps. Call only after ``validate(ingredientsById:existingRecipes:editingId:)``
    /// returned no issues.
    ///
    /// - Parameters:
    ///   - id: The recipe id (existing, or from ``newRecipeId(forName:existingIds:)``).
    ///   - source: Kept from the edited recipe; ``RecipeSource/user`` for new ones.
    ///   - isFavorite: Kept from the edited recipe.
    ///   - isHidden: Kept from the edited recipe.
    /// - Returns: The recipe, with no image asset.
    public func makeRecipe(
        id: String, source: RecipeSource, isFavorite: Bool, isHidden: Bool
    ) -> Recipe {
        Recipe(
            id: id, name: DartCompatibleText.trim(name), mealTypes: mealTypes, minutes: minutes,
            base: base,
            ingredients: ingredients.map {
                RecipeIngredient(
                    ingredientId: $0.ingredientId,
                    quantityText: DartCompatibleText.trim($0.quantityText),
                    isOptional: $0.isOptional)
            },
            steps: trimmedSteps,
            tags: DishTags(
                region: region, dishType: dishType, flavours: flavours, heaviness: heaviness,
                protein: protein),
            source: source, isFavorite: isFavorite, isHidden: isHidden)
    }

    /// A fresh id for a new user recipe: `"user_"` plus a lower-case ASCII
    /// slug of `name` (other characters become `_`; `"recipe"` if nothing is
    /// left), with `_2`, `_3`... appended until it is unused. Always matches
    /// ``SeedValidator/idPattern``.
    ///
    /// - Parameters:
    ///   - name: The recipe name.
    ///   - existingIds: Every id already in the recipe book.
    /// - Returns: The unused id.
    public static func newRecipeId(forName name: String, existingIds: Set<String>) -> String {
        let base = SeedValidator.userIdPrefix + slug(name)
        var candidate = base
        var suffix = 2
        while existingIds.contains(candidate) {
            candidate = "\(base)_\(suffix)"
            suffix += 1
        }
        return candidate
    }

    private static func slug(_ name: String) -> String {
        var words: [String] = []
        var current = ""
        for scalar in IngredientNormalizer.normalise(name).unicodeScalars {
            if ("a"..."z").contains(scalar) || ("0"..."9").contains(scalar) {
                current.unicodeScalars.append(scalar)
            } else if !current.isEmpty {
                words.append(current)
                current = ""
            }
        }
        if !current.isEmpty { words.append(current) }
        return words.isEmpty ? "recipe" : words.joined(separator: "_")
    }

    private var trimmedSteps: [String] {
        steps.map(DartCompatibleText.trim).filter { !$0.isEmpty }
    }

    private var isBaseAllowed: Bool {
        switch dishType {
        case .rice: base == .rice
        case .bread: base == .roti || base == .bread
        default: true
        }
    }

    private func ingredientIssues(_ catalog: [String: Ingredient]) -> [RecipeDraftIssue] {
        var issues: [RecipeDraftIssue] = []
        if ingredients.isEmpty { issues.append(.noIngredients) }
        var seen = Set<String>()
        for line in ingredients {
            if catalog[line.ingredientId] == nil {
                issues.append(.unknownIngredient(line.ingredientId))
            }
            if !seen.insert(line.ingredientId).inserted {
                issues.append(.repeatedIngredient(line.ingredientId))
            }
        }
        let hasCore = ingredients.contains {
            !$0.isOptional && catalog[$0.ingredientId]?.role == .core
        }
        if !hasCore { issues.append(.noCoreIngredient) }
        return issues
    }
}
