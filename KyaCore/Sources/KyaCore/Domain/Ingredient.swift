/// A canonical kitchen ingredient — the single source of truth an ingredient id
/// ever refers to. "Potato", "aloo" and "batata" are three ``aliases`` of one
/// `Ingredient`, never three separate rows.
///
/// Matching is always exact on ``id`` after alias resolution (see
/// ``IngredientNormalizer``), never a substring match.
///
/// **Equality is identity-by-id** (mirroring the Dart original): two values
/// with the same ``id`` are `==` and hash equally even if every other field
/// differs, so a `Set<Ingredient>` deduplicates by id. Ids are compared
/// case-sensitively. Use ``isIdentical(to:)`` when every field must match
/// (e.g. backup round-trip checks).
public struct Ingredient: Sendable, Hashable, CustomStringConvertible {
    /// Canonical, stable identifier — e.g. `"potato"`. Must never change once
    /// seeded (seed data is versioned).
    public let id: String

    /// Display name shown in the UI, e.g. `"Potato"`.
    public let name: String

    /// Other names/spellings a user might type, e.g. `["aloo", "batata"]`.
    /// Used by ``IngredientNormalizer``, never by substring search elsewhere.
    public let aliases: [String]

    /// Pantry-screen grouping.
    public let category: IngredientCategory

    /// Scoring importance of this ingredient.
    public let role: IngredientRole

    /// Shopping-screen vendor grouping.
    public let buyFrom: BuyFrom

    /// Typical shelf life in days once bought/opened, used to estimate an
    /// expiry date (see ``PantryItem/estimatedExpiry(updatedAt:shelfLifeDays:calendar:)``).
    /// `nil` means "doesn't meaningfully expire" (e.g. salt).
    public let shelfLifeDays: Int?

    /// True if this row was created on the fly because a user typed a name that
    /// matched nothing in the catalog (see
    /// ``IngredientNormalizer/createUserIngredient(_:category:buyFrom:role:)``).
    public let isUserCreated: Bool

    /// Creates an ingredient.
    ///
    /// - Parameters:
    ///   - id: Canonical, stable identifier.
    ///   - name: Display name.
    ///   - aliases: Alternative names; defaults to none.
    ///   - category: Pantry-screen grouping.
    ///   - role: Scoring importance.
    ///   - buyFrom: Shopping-screen vendor grouping.
    ///   - shelfLifeDays: Typical shelf life; defaults to `nil` (no expiry).
    ///   - isUserCreated: Whether the user created it; defaults to `false`.
    public init(
        id: String,
        name: String,
        aliases: [String] = [],
        category: IngredientCategory,
        role: IngredientRole,
        buyFrom: BuyFrom,
        shelfLifeDays: Int? = nil,
        isUserCreated: Bool = false
    ) {
        self.id = id
        self.name = name
        self.aliases = aliases
        self.category = category
        self.role = role
        self.buyFrom = buyFrom
        self.shelfLifeDays = shelfLifeDays
        self.isUserCreated = isUserCreated
    }

    /// Returns a copy with the given non-optional fields replaced; every `nil`
    /// argument keeps the current value. Use ``withShelfLifeDays(_:)`` to change
    /// (or clear) the optional shelf life.
    ///
    /// - Parameters:
    ///   - id: Replacement id, or `nil` to keep.
    ///   - name: Replacement name, or `nil` to keep.
    ///   - aliases: Replacement aliases, or `nil` to keep.
    ///   - category: Replacement category, or `nil` to keep.
    ///   - role: Replacement role, or `nil` to keep.
    ///   - buyFrom: Replacement vendor, or `nil` to keep.
    ///   - isUserCreated: Replacement flag, or `nil` to keep.
    /// - Returns: The modified copy; `self` is unchanged.
    public func copy(
        id: String? = nil,
        name: String? = nil,
        aliases: [String]? = nil,
        category: IngredientCategory? = nil,
        role: IngredientRole? = nil,
        buyFrom: BuyFrom? = nil,
        isUserCreated: Bool? = nil
    ) -> Ingredient {
        Ingredient(
            id: id ?? self.id,
            name: name ?? self.name,
            aliases: aliases ?? self.aliases,
            category: category ?? self.category,
            role: role ?? self.role,
            buyFrom: buyFrom ?? self.buyFrom,
            shelfLifeDays: shelfLifeDays,
            isUserCreated: isUserCreated ?? self.isUserCreated
        )
    }

    /// Returns a copy with ``shelfLifeDays`` set to `days`; passing `nil`
    /// clears it ("doesn't meaningfully expire").
    ///
    /// - Parameter days: The new shelf life, or `nil` to clear it.
    /// - Returns: The modified copy; `self` is unchanged.
    public func withShelfLifeDays(_ days: Int?) -> Ingredient {
        Ingredient(
            id: id,
            name: name,
            aliases: aliases,
            category: category,
            role: role,
            buyFrom: buyFrom,
            shelfLifeDays: days,
            isUserCreated: isUserCreated
        )
    }

    /// Field-by-field comparison, unlike `==` which compares ``id`` only.
    ///
    /// - Parameter other: The ingredient to compare against.
    /// - Returns: `true` only if every stored field is equal.
    public func isIdentical(to other: Ingredient) -> Bool {
        id == other.id && name == other.name && aliases == other.aliases
            && category == other.category && role == other.role
            && buyFrom == other.buyFrom && shelfLifeDays == other.shelfLifeDays
            && isUserCreated == other.isUserCreated
    }

    /// Identity-by-id equality (see the type documentation).
    public static func == (lhs: Ingredient, rhs: Ingredient) -> Bool {
        lhs.id == rhs.id
    }

    /// Hashes ``id`` only, consistent with `==`.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// Identifies the ingredient by id, e.g. `"Ingredient(potato)"`.
    public var description: String { "Ingredient(\(id))" }
}
