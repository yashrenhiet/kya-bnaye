/// Recipe rules R1–R11 for ``SeedValidator``. Internal.
///
/// Each recipe is checked in the Dart oracle's order — identity (R1), basics
/// (R2–R4), ingredients (R5–R7), tags (R8, R10, R11), image (R9) — so the
/// issue list is ordered exactly like the oracle's.
struct SeedRecipeRules {
    /// Allowed `minutes` range (R3), inclusive.
    static let minutes = 1...240
    /// Allowed step count (R4), inclusive.
    static let stepCount = 2...12
    /// Longest allowed step text (R4), in UTF-16 code units like Dart's
    /// `String.length`.
    static let maxStepLength = 200
    /// Most required core/flavor ingredients a user may have to shop for (R7).
    static let maxShoppableIngredients = 8
    /// Folder, relative to `seed/`, every recipe image lives in (R9).
    static let imageDirectory = "images"

    /// Ingredient ids that make a dish carry a given protein tag (R11), in the
    /// oracle's order.
    static let proteinIngredientIds: [(protein: Protein, ids: [String])] = [
        (.paneer, ["paneer"]),
        (.egg, ["eggs"]),
        (.chicken, ["chicken"]),
        (.mutton, ["mutton"]),
        (.fish, ["fish", "prawns"]),
    ]

    private let catalogue: [String: Ingredient]
    private var issues: [SeedIssue] = []

    private init(catalogue: [String: Ingredient]) {
        self.catalogue = catalogue
    }

    /// Every R1–R11 issue in `bundle`, in the oracle's order.
    static func check(_ bundle: SeedBundle, assetExists: (String) -> Bool) -> [SeedIssue] {
        var catalogue: [String: Ingredient] = [:]
        for ingredient in bundle.ingredients { catalogue[ingredient.id] = ingredient }
        var rules = SeedRecipeRules(catalogue: catalogue)
        var ids = Set<String>()
        var nameOwners: [String: String] = [:]
        for recipe in bundle.recipes {
            rules.identity(recipe, ids: &ids, nameOwners: &nameOwners)
            rules.basics(recipe)
            rules.ingredients(recipe)
            rules.tags(recipe)
            rules.image(recipe, assetExists: assetExists)
        }
        return rules.issues
    }

    private mutating func issue(
        _ code: SeedIssueCode, _ recipe: Recipe, _ field: String, _ message: String
    ) {
        issues.append(SeedIssue(code, "recipes[\(recipe.id)]\(field)", message))
    }

    private mutating func identity(
        _ recipe: Recipe, ids: inout Set<String>, nameOwners: inout [String: String]
    ) {
        if !SeedValidator.isValidId(recipe.id) {
            issue(.r1RecipeIdentity, recipe, "", "id must match \(SeedValidator.idPattern)")
        }
        if !ids.insert(recipe.id).inserted {
            issue(.r1RecipeIdentity, recipe, "", "duplicate id")
        }
        let trimmed = DartCompatibleText.trim(recipe.name)
        if trimmed.isEmpty {
            issue(.r1RecipeIdentity, recipe, ".name", "name is blank")
            return
        }
        if recipe.name != trimmed {
            issue(.r1RecipeIdentity, recipe, ".name", "name has surrounding whitespace")
        }
        let key = IngredientNormalizer.normalise(recipe.name)
        let owner = nameOwners[key, default: recipe.id]
        nameOwners[key] = owner
        if owner != recipe.id {
            issue(
                .r1RecipeIdentity, recipe, ".name",
                "name \"\(recipe.name)\" is also used by \(owner)")
        }
    }

    private mutating func basics(_ recipe: Recipe) {
        if recipe.mealTypes.isEmpty {
            issue(.r2MealTypes, recipe, ".mealTypes", "no meal types")
        }
        if !Self.minutes.contains(recipe.minutes) {
            issue(
                .r3Minutes, recipe, ".minutes",
                "\(recipe.minutes) is outside \(Self.minutes.lowerBound)–\(Self.minutes.upperBound)"
            )
        }
        let steps = recipe.steps.count
        if !Self.stepCount.contains(steps) {
            issue(
                .r4Steps, recipe, ".steps",
                "\(steps) steps; expected \(Self.stepCount.lowerBound)–\(Self.stepCount.upperBound)"
            )
        }
        for (index, step) in recipe.steps.enumerated() {
            let length = step.utf16.count
            if DartCompatibleText.trim(step).isEmpty {
                issue(.r4Steps, recipe, ".steps[\(index)]", "blank step")
            } else if length > Self.maxStepLength {
                issue(
                    .r4Steps, recipe, ".steps[\(index)]",
                    "\(length) characters; at most \(Self.maxStepLength)")
            }
        }
    }

    private mutating func ingredients(_ recipe: Recipe) {
        if recipe.ingredients.isEmpty {
            issue(.r5Ingredients, recipe, ".ingredients", "no ingredients")
        }
        var seen = Set<String>()
        for (index, line) in recipe.ingredients.enumerated() {
            let field = ".ingredients[\(index)]"
            if catalogue[line.ingredientId] == nil {
                issue(.r5Ingredients, recipe, field, "unknown ingredient \"\(line.ingredientId)\"")
            }
            if !seen.insert(line.ingredientId).inserted {
                issue(
                    .r5Ingredients, recipe, field, "ingredient \"\(line.ingredientId)\" is repeated"
                )
            }
            if DartCompatibleText.trim(line.quantityText).isEmpty {
                issue(.r5Ingredients, recipe, field, "blank quantityText")
            }
        }
        let roles = recipe.requiredIngredients.map { catalogue[$0.ingredientId]?.role }
        if !roles.contains(.core) {
            issue(
                .r6CoreIngredient, recipe, ".ingredients",
                "no required ingredient has the core role")
        }
        let shoppable = roles.count { $0 == .core || $0 == .flavor }
        if shoppable > Self.maxShoppableIngredients {
            issue(
                .r7RequiredCount, recipe, ".ingredients",
                "\(shoppable) required core/flavor ingredients; at most "
                    + "\(Self.maxShoppableIngredients)")
        }
    }

    private mutating func tags(_ recipe: Recipe) {
        let tags = recipe.tags
        if tags.flavours.isEmpty {
            issue(.r8Flavours, recipe, ".tags.flavours", "no flavours")
        } else if tags.flavours.isSuperset(of: [.mild, .spicy]) {
            issue(.r8Flavours, recipe, ".tags.flavours", "a dish cannot be both mild and spicy")
        }
        let allowedBases: [DishBase]? =
            switch tags.dishType {
            case .rice: [.rice]
            case .bread: [.roti, .bread]
            default: nil
            }
        if let allowedBases, !allowedBases.contains(recipe.base) {
            let names = allowedBases.map(\.rawValue).joined(separator: " or ")
            issue(
                .r10Base, recipe, ".base",
                "a \(tags.dishType.rawValue) dish needs base \(names), not \(recipe.base.rawValue)")
        }
        protein(recipe)
    }

    private mutating func protein(_ recipe: Recipe) {
        let protein = recipe.tags.protein
        let requiredIds = Set(recipe.requiredIngredients.map(\.ingredientId))
        let expected = Self.proteinIngredientIds.first { $0.protein == protein }?.ids
        if let expected, requiredIds.isDisjoint(with: expected) {
            issue(
                .r11Protein, recipe, ".tags.protein",
                "\(protein.rawValue) needs a required ingredient: "
                    + expected.joined(separator: " or "))
        } else if protein == .dalLegume,
            !requiredIds.contains(where: { catalogue[$0]?.category == .dal })
        {
            issue(.r11Protein, recipe, ".tags.protein", "dalLegume needs a required dal ingredient")
        } else if protein == .vegOnly {
            let animal = Set(Self.proteinIngredientIds.flatMap(\.ids))
            let found = recipe.ingredients.map(\.ingredientId).filter(animal.contains)
            if !found.isEmpty {
                issue(
                    .r11Protein, recipe, ".tags.protein",
                    "vegOnly dish contains \(found.joined(separator: ", "))")
            }
        }
    }

    private mutating func image(_ recipe: Recipe, assetExists: (String) -> Bool) {
        guard let path = recipe.imageAsset else { return }
        let expected = "\(Self.imageDirectory)/\(recipe.id).webp"
        if path != expected {
            issue(.r9ImageAsset, recipe, ".imageAsset", "\"\(path)\" must be \"\(expected)\"")
        } else if !assetExists(path) {
            issue(.r9ImageAsset, recipe, ".imageAsset", "\"\(path)\" not found")
        }
    }
}
