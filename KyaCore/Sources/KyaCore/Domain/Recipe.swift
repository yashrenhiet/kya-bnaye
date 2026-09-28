/// Where a ``Recipe`` came from.
public enum RecipeSource: String, Sendable, CaseIterable, Codable {
    /// Shipped in the bundled seed data.
    case seed
    /// Created by the user.
    case user
}

/// A dish: everything needed to decide whether to recommend it, show it in the
/// swipe deck, and cook it.
///
/// **Equality is identity-by-id** (mirroring the Dart original): two recipes
/// with the same ``id`` are `==` and hash equally even if every other field
/// differs. Use ``isIdentical(to:)`` when every field must match.
public struct Recipe: Sendable, Hashable, CustomStringConvertible {
    /// Canonical, stable identifier, e.g. `"dal_tadka"`.
    public let id: String

    /// Display name, e.g. `"Dal Tadka"`.
    public let name: String

    /// Which meal slots this dish fits — a set, not a single value.
    public let mealTypes: Set<MealType>

    /// Typical cooking time in minutes.
    public let minutes: Int

    /// Starch base, for the "rice after rice" rotation penalty.
    public let base: DishBase

    /// Ingredient lines in display order.
    public let ingredients: [RecipeIngredient]

    /// Cooking steps in order.
    public let steps: [String]

    /// Closed-enum tags used by the rankers.
    public let tags: DishTags

    /// Bundled image path; `nil` makes the UI fall back to a generated
    /// gradient + initial card.
    public let imageAsset: String?

    /// Whether the user starred this recipe.
    public let isFavorite: Bool

    /// "Never show" — excluded from every deck until un-hidden in Settings.
    public let isHidden: Bool

    /// Where the recipe came from.
    public let source: RecipeSource

    /// Creates a recipe.
    ///
    /// - Parameters:
    ///   - id: Canonical, stable identifier.
    ///   - name: Display name.
    ///   - mealTypes: Meal slots the dish fits.
    ///   - minutes: Typical cooking time.
    ///   - base: Starch base.
    ///   - ingredients: Ingredient lines in display order.
    ///   - steps: Cooking steps in order.
    ///   - tags: Closed-enum tags.
    ///   - source: Where the recipe came from.
    ///   - imageAsset: Bundled image path; defaults to `nil`.
    ///   - isFavorite: Defaults to `false`.
    ///   - isHidden: Defaults to `false`.
    public init(
        id: String,
        name: String,
        mealTypes: Set<MealType>,
        minutes: Int,
        base: DishBase,
        ingredients: [RecipeIngredient],
        steps: [String],
        tags: DishTags,
        source: RecipeSource,
        imageAsset: String? = nil,
        isFavorite: Bool = false,
        isHidden: Bool = false
    ) {
        self.id = id
        self.name = name
        self.mealTypes = mealTypes
        self.minutes = minutes
        self.base = base
        self.ingredients = ingredients
        self.steps = steps
        self.tags = tags
        self.source = source
        self.imageAsset = imageAsset
        self.isFavorite = isFavorite
        self.isHidden = isHidden
    }

    /// Non-optional ingredient lines only — the ones that count toward
    /// "missing" — in their original order.
    public var requiredIngredients: [RecipeIngredient] {
        ingredients.filter { !$0.isOptional }
    }

    /// Returns a copy with the given non-optional fields replaced; every `nil`
    /// argument keeps the current value. Use ``withImageAsset(_:)`` to change
    /// (or clear) the optional image.
    ///
    /// - Parameters:
    ///   - id: Replacement id, or `nil` to keep.
    ///   - name: Replacement name, or `nil` to keep.
    ///   - mealTypes: Replacement meal types, or `nil` to keep.
    ///   - minutes: Replacement cooking time, or `nil` to keep.
    ///   - base: Replacement base, or `nil` to keep.
    ///   - ingredients: Replacement lines, or `nil` to keep.
    ///   - steps: Replacement steps, or `nil` to keep.
    ///   - tags: Replacement tags, or `nil` to keep.
    ///   - source: Replacement source, or `nil` to keep.
    ///   - isFavorite: Replacement flag, or `nil` to keep.
    ///   - isHidden: Replacement flag, or `nil` to keep.
    /// - Returns: The modified copy; `self` is unchanged.
    public func copy(
        id: String? = nil,
        name: String? = nil,
        mealTypes: Set<MealType>? = nil,
        minutes: Int? = nil,
        base: DishBase? = nil,
        ingredients: [RecipeIngredient]? = nil,
        steps: [String]? = nil,
        tags: DishTags? = nil,
        source: RecipeSource? = nil,
        isFavorite: Bool? = nil,
        isHidden: Bool? = nil
    ) -> Recipe {
        Recipe(
            id: id ?? self.id,
            name: name ?? self.name,
            mealTypes: mealTypes ?? self.mealTypes,
            minutes: minutes ?? self.minutes,
            base: base ?? self.base,
            ingredients: ingredients ?? self.ingredients,
            steps: steps ?? self.steps,
            tags: tags ?? self.tags,
            source: source ?? self.source,
            imageAsset: imageAsset,
            isFavorite: isFavorite ?? self.isFavorite,
            isHidden: isHidden ?? self.isHidden
        )
    }

    /// Returns a copy with ``imageAsset`` set to `path`; passing `nil` clears it.
    ///
    /// - Parameter path: The new image path, or `nil` to clear it.
    /// - Returns: The modified copy; `self` is unchanged.
    public func withImageAsset(_ path: String?) -> Recipe {
        Recipe(
            id: id,
            name: name,
            mealTypes: mealTypes,
            minutes: minutes,
            base: base,
            ingredients: ingredients,
            steps: steps,
            tags: tags,
            source: source,
            imageAsset: path,
            isFavorite: isFavorite,
            isHidden: isHidden
        )
    }

    /// Field-by-field comparison, unlike `==` which compares ``id`` only.
    ///
    /// - Parameter other: The recipe to compare against.
    /// - Returns: `true` only if every stored field is equal.
    public func isIdentical(to other: Recipe) -> Bool {
        id == other.id && name == other.name && mealTypes == other.mealTypes
            && minutes == other.minutes && base == other.base
            && ingredients == other.ingredients && steps == other.steps
            && tags == other.tags && imageAsset == other.imageAsset
            && isFavorite == other.isFavorite && isHidden == other.isHidden
            && source == other.source
    }

    /// Identity-by-id equality (see the type documentation).
    public static func == (lhs: Recipe, rhs: Recipe) -> Bool {
        lhs.id == rhs.id
    }

    /// Hashes ``id`` only, consistent with `==`.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// Shows id and name, e.g. `"Recipe(dal_tadka, Dal Tadka)"`.
    public var description: String { "Recipe(\(id), \(name))" }
}
