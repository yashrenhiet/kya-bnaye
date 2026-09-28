/// Which "axis" of recipe metadata a ``TagKey`` belongs to.
///
/// Kept separate from the tag's own enum type so a taste profile can hold
/// affinities for tags from every dimension in a single `[TagKey: Double]`.
/// `allCases` order (region, dishType, flavour, heaviness, protein) is the
/// ordering used by ``TagKey``'s `Comparable` conformance.
public enum TagDimension: String, Sendable, CaseIterable, Codable, Comparable {
    /// ``Region``.
    case region
    /// ``DishType``.
    case dishType
    /// ``Flavour``.
    case flavour
    /// ``Heaviness``.
    case heaviness
    /// ``Protein``.
    case protein

    /// Declaration order: `region < dishType < flavour < heaviness < protein`.
    public static func < (lhs: TagDimension, rhs: TagDimension) -> Bool {
        lhs.ordinal < rhs.ordinal
    }

    private var ordinal: Int {
        switch self {
        case .region: 0
        case .dishType: 1
        case .flavour: 2
        case .heaviness: 3
        case .protein: 4
        }
    }
}

/// A single point of taste evidence: one value from one ``TagDimension``, e.g.
/// `TagKey.region("south")`.
///
/// Built via the typed factories (or ``TagValue/tagKey``) rather than a raw
/// initializer, so a call site can never pair the wrong enum's raw value with
/// the wrong dimension. ``value`` is a plain string so keys read from a newer
/// backup with an unknown value still round-trip instead of failing.
///
/// Equality is exact and case-sensitive over both fields. `Comparable` orders by
/// dimension, then by value, giving a deterministic order for iterating
/// dictionaries keyed by `TagKey`.
public struct TagKey: Sendable, Hashable, Comparable, CustomStringConvertible {
    /// The dimension this key belongs to.
    public let dimension: TagDimension

    /// The specific enum value's raw value, e.g. `"south"`, `"spicy"`.
    public let value: String

    init(dimension: TagDimension, value: String) {
        self.dimension = dimension
        self.value = value
    }

    /// A ``TagDimension/region`` key for the given ``Region`` raw value.
    public static func region(_ regionName: String) -> TagKey {
        TagKey(dimension: .region, value: regionName)
    }

    /// A ``TagDimension/dishType`` key for the given ``DishType`` raw value.
    public static func dishType(_ dishTypeName: String) -> TagKey {
        TagKey(dimension: .dishType, value: dishTypeName)
    }

    /// A ``TagDimension/flavour`` key for the given ``Flavour`` raw value.
    public static func flavour(_ flavourName: String) -> TagKey {
        TagKey(dimension: .flavour, value: flavourName)
    }

    /// A ``TagDimension/heaviness`` key for the given ``Heaviness`` raw value.
    public static func heaviness(_ heavinessName: String) -> TagKey {
        TagKey(dimension: .heaviness, value: heavinessName)
    }

    /// A ``TagDimension/protein`` key for the given ``Protein`` raw value.
    public static func protein(_ proteinName: String) -> TagKey {
        TagKey(dimension: .protein, value: proteinName)
    }

    /// Human label looked up from the matching tag enum, e.g. `"Indo-Chinese"`
    /// for `region:indoChinese`. An unknown value falls back to the raw
    /// ``value`` rather than failing.
    public var label: String {
        let label: String? =
            switch dimension {
            case .region: Region(rawValue: value)?.label
            case .dishType: DishType(rawValue: value)?.label
            case .flavour: Flavour(rawValue: value)?.label
            case .heaviness: Heaviness(rawValue: value)?.label
            case .protein: Protein(rawValue: value)?.label
            }
        return label ?? value
    }

    /// Renders as `dimension:value`, e.g. `"heaviness:heavy"`.
    public var description: String { "\(dimension.rawValue):\(value)" }

    /// Orders by ``dimension`` first, then by ``value``.
    public static func < (lhs: TagKey, rhs: TagKey) -> Bool {
        if lhs.dimension != rhs.dimension {
            return lhs.dimension < rhs.dimension
        }
        return lhs.value < rhs.value
    }
}
