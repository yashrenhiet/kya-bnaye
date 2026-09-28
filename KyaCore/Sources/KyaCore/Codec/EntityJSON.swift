import Foundation

/// Shared JSON mappers for the catalogue entities (ingredients and recipes).
///
/// Internal. Both ``BackupCodec`` and the strict ``SeedCodec`` map through
/// these functions, so a backup and the bundled seed data can never disagree
/// on how an entity is spelled in JSON. Field names and enum raw values are
/// byte-identical to the seed files and to the legacy Dart backups.
///
/// Encoding writes every field, with JSON `null` (`NSNull`) for `nil`
/// optionals. Sets are written in the enum's declaration order, so output is
/// deterministic (the Dart original used set insertion order). Decoding is
/// lenient about keys and strict about types (see ``JSONFields``); the seed
/// codec runs its strict key checks before calling these readers.
enum EntityJSON {
    // MARK: Ingredient

    /// JSON object for `ingredient`.
    static func json(_ ingredient: Ingredient) -> [String: Any] {
        [
            "id": ingredient.id,
            "name": ingredient.name,
            "aliases": ingredient.aliases,
            "category": ingredient.category.rawValue,
            "role": ingredient.role.rawValue,
            "buyFrom": ingredient.buyFrom.rawValue,
            "shelfLifeDays": nullable(ingredient.shelfLifeDays),
            "isUserCreated": ingredient.isUserCreated,
        ]
    }

    /// Reads an ingredient; an absent `isUserCreated` means `false`.
    static func ingredient(from value: Any?) throws(EntityJSONError) -> Ingredient {
        let fields = try JSONFields(value, entity: "ingredient")
        return Ingredient(
            id: try fields.string("id"),
            name: try fields.string("name"),
            aliases: try fields.stringList("aliases"),
            category: try fields.enumValue("category"),
            role: try fields.enumValue("role"),
            buyFrom: try fields.enumValue("buyFrom"),
            shelfLifeDays: try fields.optionalInteger("shelfLifeDays"),
            isUserCreated: try fields.flag("isUserCreated")
        )
    }

    // MARK: Recipe

    /// JSON object for `recipe`, including the app-owned fields.
    static func json(_ recipe: Recipe) -> [String: Any] {
        [
            "id": recipe.id,
            "name": recipe.name,
            "mealTypes": ordered(recipe.mealTypes),
            "minutes": recipe.minutes,
            "base": recipe.base.rawValue,
            "ingredients": recipe.ingredients.map(json(_:)),
            "steps": recipe.steps,
            "tags": json(recipe.tags),
            "imageAsset": nullable(recipe.imageAsset),
            "isFavorite": recipe.isFavorite,
            "isHidden": recipe.isHidden,
            "source": recipe.source.rawValue,
        ]
    }

    /// Reads a recipe; `source` is required, absent flags mean `false`.
    /// Fields are read in the Dart oracle's order, so the first problem
    /// reported is the same one the oracle reports.
    static func recipe(from value: Any?) throws(EntityJSONError) -> Recipe {
        let fields = try JSONFields(value, entity: "recipe")
        let id = try fields.string("id")
        let name = try fields.string("name")
        let mealTypes: Set<MealType> = try fields.enumSet("mealTypes")
        let minutes = try fields.integer("minutes")
        let base: DishBase = try fields.enumValue("base")
        var lines: [RecipeIngredient] = []
        for (index, line) in try fields.array("ingredients").enumerated() {
            lines.append(try recipeIngredient(from: line, entity: "recipe.ingredients[\(index)]"))
        }
        let steps = try fields.stringList("steps")
        let tags = try dishTags(from: try fields.object("tags", entity: "tags"))
        return Recipe(
            id: id,
            name: name,
            mealTypes: mealTypes,
            minutes: minutes,
            base: base,
            ingredients: lines,
            steps: steps,
            tags: tags,
            source: try fields.enumValue("source"),
            imageAsset: try fields.optionalString("imageAsset"),
            isFavorite: try fields.flag("isFavorite"),
            isHidden: try fields.flag("isHidden")
        )
    }

    // MARK: RecipeIngredient / DishTags

    /// JSON object for one recipe line.
    static func json(_ line: RecipeIngredient) -> [String: Any] {
        [
            "ingredientId": line.ingredientId,
            "quantityText": line.quantityText,
            "isOptional": line.isOptional,
        ]
    }

    private static func recipeIngredient(
        from value: Any?, entity: String
    ) throws(EntityJSONError) -> RecipeIngredient {
        let fields = try JSONFields(value, entity: entity)
        return RecipeIngredient(
            ingredientId: try fields.string("ingredientId"),
            quantityText: try fields.string("quantityText"),
            isOptional: try fields.flag("isOptional")
        )
    }

    /// JSON object for `tags`.
    static func json(_ tags: DishTags) -> [String: Any] {
        [
            "region": tags.region.rawValue,
            "dishType": tags.dishType.rawValue,
            "flavours": ordered(tags.flavours),
            "heaviness": tags.heaviness.rawValue,
            "protein": tags.protein.rawValue,
        ]
    }

    private static func dishTags(from fields: JSONFields) throws(EntityJSONError) -> DishTags {
        DishTags(
            region: try fields.enumValue("region"),
            dishType: try fields.enumValue("dishType"),
            flavours: try fields.enumSet("flavours"),
            heaviness: try fields.enumValue("heaviness"),
            protein: try fields.enumValue("protein")
        )
    }

    // MARK: Helpers

    /// `value`, or `NSNull` (JSON `null`) when `nil`.
    static func nullable(_ value: (some Any)?) -> Any {
        value.map { $0 as Any } ?? NSNull()
    }

    /// Raw values of `values` in the enum's declaration order.
    static func ordered<T: CaseIterable & RawRepresentable & Hashable>(
        _ values: Set<T>
    ) -> [String] where T.RawValue == String {
        T.allCases.filter(values.contains).map(\.rawValue)
    }
}
