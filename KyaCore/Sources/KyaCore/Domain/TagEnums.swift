// Closed-enum recipe metadata used by both rankers. No free text: seed
// validators reject anything that doesn't map to these enums, so the taste
// profile can never fragment over spelling drift.
//
// Raw values are byte-identical to the legacy Dart enum `.name` values used in
// seed and backup JSON; `allCases` preserves the Dart declaration order.

/// A value with a human-readable display label.
///
/// `rawValue` stays the stable persistence / ``TagKey`` value; ``label`` is
/// display-only and free to change.
public protocol TagLabelled {
    /// Display text for explanations and chips, e.g. "South Indian",
    /// "dry sabzi". Proper nouns are capitalised; everything else is lower
    /// case so it reads naturally mid-sentence.
    var label: String { get }
}

/// A closed tag enum belonging to exactly one ``TagDimension``.
public protocol TagValue: TagLabelled, CaseIterable, Hashable, Sendable, RawRepresentable
where RawValue == String {
    /// The dimension every case of this enum belongs to.
    static var dimension: TagDimension { get }
}

extension TagValue {
    /// The ``TagKey`` for this value: its type's ``TagValue/dimension`` paired
    /// with its `rawValue`.
    public var tagKey: TagKey { TagKey(dimension: Self.dimension, value: rawValue) }
}

/// Regional cuisine of a dish.
public enum Region: String, TagValue, Codable {
    /// North Indian.
    case north
    /// South Indian.
    case south
    /// East Indian.
    case east
    /// West Indian.
    case west
    /// Gujarati.
    case gujarati
    /// Punjabi.
    case punjabi
    /// Indo-Chinese.
    case indoChinese
    /// Continental.
    case continental
    /// Street food.
    case street

    /// Always ``TagDimension/region``.
    public static var dimension: TagDimension { .region }

    /// Human label, e.g. "Indo-Chinese".
    public var label: String {
        switch self {
        case .north: "North Indian"
        case .south: "South Indian"
        case .east: "East Indian"
        case .west: "West Indian"
        case .gujarati: "Gujarati"
        case .punjabi: "Punjabi"
        case .indoChinese: "Indo-Chinese"
        case .continental: "Continental"
        case .street: "street food"
        }
    }
}

/// The kind of dish.
public enum DishType: String, TagValue, Codable {
    /// Dal.
    case dal
    /// Curry.
    case curry
    /// Dry sabzi.
    case drySabzi
    /// Rice dish.
    case rice
    /// Bread.
    case bread
    /// Breakfast dish.
    case breakfast
    /// Snack.
    case snack
    /// Sweet.
    case sweet
    /// One-pot meal.
    case onePot

    /// Always ``TagDimension/dishType``.
    public static var dimension: TagDimension { .dishType }

    /// Human label, e.g. "dry sabzi".
    public var label: String {
        switch self {
        case .dal: "dal"
        case .curry: "curry"
        case .drySabzi: "dry sabzi"
        case .rice: "rice"
        case .bread: "bread"
        case .breakfast: "breakfast"
        case .snack: "snacks"
        case .sweet: "sweets"
        case .onePot: "one-pot meals"
        }
    }
}

/// A flavour note; a dish carries a set of these.
public enum Flavour: String, TagValue, Codable {
    /// Spicy.
    case spicy
    /// Tangy.
    case tangy
    /// Sweet.
    case sweet
    /// Savoury.
    case savoury
    /// Mild.
    case mild

    /// Always ``TagDimension/flavour``.
    public static var dimension: TagDimension { .flavour }

    /// Human label; identical to the raw value for every flavour.
    public var label: String { rawValue }
}

/// How filling a dish is.
public enum Heaviness: String, TagValue, Codable {
    /// Light.
    case light
    /// Medium.
    case medium
    /// Heavy.
    case heavy

    /// Always ``TagDimension/heaviness``.
    public static var dimension: TagDimension { .heaviness }

    /// Human label, e.g. "hearty meals".
    public var label: String {
        switch self {
        case .light: "light meals"
        case .medium: "medium-weight meals"
        case .heavy: "hearty meals"
        }
    }
}

/// Main protein of a dish. Tag-only in v1 — diet filtering is deferred to v2,
/// but the taste profile can still learn "you tend to pick paneer dishes".
public enum Protein: String, TagValue, Codable {
    /// Paneer.
    case paneer
    /// Dal and legumes.
    case dalLegume
    /// Egg.
    case egg
    /// Chicken.
    case chicken
    /// Mutton.
    case mutton
    /// Fish.
    case fish
    /// Vegetarian with no dominant protein.
    case vegOnly

    /// Always ``TagDimension/protein``.
    public static var dimension: TagDimension { .protein }

    /// Human label, e.g. "dal and legumes".
    public var label: String {
        switch self {
        case .paneer: "paneer"
        case .dalLegume: "dal and legumes"
        case .egg: "egg"
        case .chicken: "chicken"
        case .mutton: "mutton"
        case .fish: "fish"
        case .vegOnly: "veg"
        }
    }
}

/// A meal slot a dish can be eaten in.
public enum MealType: String, Sendable, CaseIterable, Codable {
    /// Breakfast.
    case breakfast
    /// Lunch.
    case lunch
    /// Dinner.
    case dinner
    /// Snack.
    case snack
}

/// A recipe's starch base — used for the "rice after rice" rotation penalty.
public enum DishBase: String, Sendable, CaseIterable, Codable {
    /// Rice.
    case rice
    /// Roti.
    case roti
    /// Bread.
    case bread
    /// No starch base.
    case none
}
