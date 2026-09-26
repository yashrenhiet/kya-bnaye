/// Closed enums shared across the domain layer.
///
/// Kept as real Dart `enum`s (not strings) so invalid values are a compile
/// error, not a runtime surprise — see `AGENTS.md` section 0 (no silent
/// failures) and the seed-data validators planned for milestone M2.
library;

/// How much of an `Ingredient` is currently at home.
///
/// Deliberately coarse (ADR 005) — no quantities, no units. This is the
/// entire pantry-logging model: a single tap cycles `plenty → low → out`.
enum StockLevel {
  plenty,
  low,
  out;

  /// True if this level should be treated as "available" when checking
  /// whether a recipe can be cooked. `low` still counts as available — it's
  /// a warning to restock soon, not an absence.
  bool get isAvailable => this != StockLevel.out;
}

/// Where an ingredient normally lives in a pantry, purely for grouping the
/// Pantry screen (F2) into sections a household actually thinks in.
enum IngredientCategory {
  sabzi,
  fruit,
  dairy,
  grains,
  dal,
  masala,
  oilGhee,
  packaged,
  other,
}

/// How important an ingredient is to a dish tasting "right".
///
/// This is the single biggest lever in Kitchen-mode scoring (see
/// `docs/design/RECOMMENDER.md` section 5): missing a `core` ingredient
/// tanks a recipe's score far more than missing a `staple`.
enum IngredientRole {
  /// Defines the dish — missing it usually means "don't make this".
  core,

  /// Shapes the flavour (a masala, a specific spice) but the dish still
  /// works, just tastes different, without it.
  flavor,

  /// A garnish or nice-to-have. Never counts as "missing".
  optional,

  /// Assumed present unless explicitly marked [StockLevel.out] (salt, oil,
  /// water, haldi...). See `AGENTS.md` design principle 2.
  staple,
}

/// Where a household typically buys an ingredient — drives the Shopping
/// screen's (F6) vendor grouping, not the Pantry screen's grouping.
enum BuyFrom { sabziwala, kirana, dairy, other }
