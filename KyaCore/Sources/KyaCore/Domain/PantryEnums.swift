// Closed enums shared across the pantry side of the domain layer.
//
// Raw values are byte-identical to the legacy Dart enum `.name` values used in
// seed and backup JSON (`AGENTS.md` section 5.4), and `allCases` preserves the
// Dart declaration order.

/// How much of an ``Ingredient`` is currently at home.
///
/// Deliberately coarse (ADR 005) — no quantities, no units. A single tap cycles
/// `plenty → low → out`.
public enum StockLevel: String, Sendable, CaseIterable, Codable {
    /// Well stocked.
    case plenty
    /// Running low — a nudge to restock, but still usable.
    case low
    /// None left at home.
    case out

    /// Whether this level counts as "available" when checking if a recipe can
    /// be cooked. `low` still counts as available — it is a warning to restock
    /// soon, not an absence.
    public var isAvailable: Bool { self != .out }
}

/// Where an ingredient normally lives in a pantry, used to group the Pantry
/// screen into sections a household actually thinks in.
public enum IngredientCategory: String, Sendable, CaseIterable, Codable {
    /// Fresh vegetables.
    case sabzi
    /// Fresh fruit.
    case fruit
    /// Milk, curd, paneer and friends.
    case dairy
    /// Rice, atta and other grains or flours.
    case grains
    /// Lentils and pulses.
    case dal
    /// Whole and ground spices.
    case masala
    /// Cooking oils and ghee.
    case oilGhee
    /// Packaged and processed goods.
    case packaged
    /// Anything that fits nowhere else.
    case other
}

/// How important an ingredient is to a dish tasting "right".
///
/// The single biggest lever in Kitchen-mode scoring: missing a `core`
/// ingredient tanks a recipe's score far more than missing a `staple`.
public enum IngredientRole: String, Sendable, CaseIterable, Codable {
    /// Defines the dish — missing it usually means "don't make this".
    case core
    /// Shapes the flavour, but the dish still works without it.
    case flavor
    /// A garnish or nice-to-have. Never counts as "missing".
    case optional
    /// Assumed present unless explicitly marked ``StockLevel/out`` (salt, oil,
    /// water, haldi...).
    case staple
}

/// Where a household typically buys an ingredient — drives the Shopping
/// screen's vendor grouping.
public enum BuyFrom: String, Sendable, CaseIterable, Codable {
    /// The vegetable vendor.
    case sabziwala
    /// The neighbourhood grocery store.
    case kirana
    /// The milk/dairy vendor.
    case dairy
    /// Anywhere else.
    case other
}
