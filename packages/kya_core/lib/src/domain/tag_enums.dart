/// Closed-enum recipe metadata used by both rankers
/// (`docs/design/RECOMMENDER.md` sections 3–5). No free text: seed-data
/// validators (milestone M2) reject anything that doesn't map to these
/// enums, so the taste profile can never fragment over spelling drift.
library;

enum Region {
  north,
  south,
  east,
  west,
  gujarati,
  punjabi,
  indoChinese,
  continental,
  street,
}

enum DishType {
  dal,
  curry,
  drySabzi,
  rice,
  bread,
  breakfast,
  snack,
  sweet,
  onePot,
}

enum Flavour { spicy, tangy, sweet, savoury, mild }

enum Heaviness { light, medium, heavy }

/// Tag-only in v1 — diet *filtering* (veg/Jain/etc.) is deferred to v2
/// (ADR/decision D3). This still lets the taste profile learn "you tend to
/// pick paneer dishes" today.
enum Protein { paneer, dalLegume, egg, chicken, mutton, fish, vegOnly }

enum MealType { breakfast, lunch, dinner, snack }

/// What a recipe's starch base is — used for the "rice after rice" rotation
/// penalty (`docs/design/RECOMMENDER.md` section 5).
enum DishBase { rice, roti, bread, none }
