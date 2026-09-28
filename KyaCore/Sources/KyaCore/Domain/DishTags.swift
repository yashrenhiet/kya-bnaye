/// Closed-enum metadata attached to every ``Recipe``, used by both rankers.
///
/// Equality and hashing are value-based over every field; ``flavours`` is a set,
/// so its iteration order never affects equality.
public struct DishTags: Sendable, Hashable {
    /// Regional cuisine.
    public let region: Region
    /// Kind of dish.
    public let dishType: DishType
    /// A dish can be both spicy and tangy — deliberately a set, not a single
    /// value. Seed data requires it to be non-empty; this type does not.
    public let flavours: Set<Flavour>
    /// How filling the dish is.
    public let heaviness: Heaviness
    /// Main protein.
    public let protein: Protein

    /// Creates dish tags from their five dimensions.
    ///
    /// - Parameters:
    ///   - region: Regional cuisine.
    ///   - dishType: Kind of dish.
    ///   - flavours: Flavour notes (may be empty).
    ///   - heaviness: How filling the dish is.
    ///   - protein: Main protein.
    public init(
        region: Region,
        dishType: DishType,
        flavours: Set<Flavour>,
        heaviness: Heaviness,
        protein: Protein
    ) {
        self.region = region
        self.dishType = dishType
        self.flavours = flavours
        self.heaviness = heaviness
        self.protein = protein
    }

    /// Every ``TagKey`` this dish carries, across all dimensions.
    ///
    /// Deterministic order: region, dish type, each flavour in ``Flavour``
    /// declaration order, heaviness, protein. (The Dart original used set
    /// insertion order for flavours; Swift sets are unordered, so declaration
    /// order is used instead.) Never contains duplicates.
    public var allKeys: [TagKey] {
        var keys = [region.tagKey, dishType.tagKey]
        keys += Flavour.allCases.filter(flavours.contains).map(\.tagKey)
        keys += [heaviness.tagKey, protein.tagKey]
        return keys
    }
}
