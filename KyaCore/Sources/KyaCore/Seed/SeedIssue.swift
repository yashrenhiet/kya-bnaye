/// Which seed-data rule a ``SeedIssue`` breaks. Rule ids (`I1`…`R11`) match
/// `docs/design/SEED_GUIDE.md` section 7; coverage codes are only reported
/// when ``SeedValidator/validate(_:assetExists:coverage:exemptions:)`` is
/// given ``SeedCoverageTargets``. The raw value is the rule id.
public enum SeedIssueCode: String, Sendable, CaseIterable {
    /// I1: ingredient id format (`^[a-z][a-z0-9_]*$`, no `user_` prefix) and
    /// uniqueness.
    case i1IngredientId = "I1"
    /// I2: ingredient name non-blank, trimmed, unique after normalising.
    case i2IngredientName = "I2"
    /// I3: every normalised name/alias maps to exactly one ingredient, and no
    /// alias repeats within an ingredient or equals its own name.
    case i3AliasCollision = "I3"
    /// I4: aliases non-blank and already normalised (lowercase, trimmed,
    /// single-spaced).
    case i4AliasFormat = "I4"
    /// I5: `shelfLifeDays` in range, and present for perishables.
    case i5ShelfLife = "I5"
    /// I6: sabzi/fruit bought from the sabziwala, dairy from the dairy.
    case i6BuyFrom = "I6"
    /// I7: staple count and which categories may be staples.
    case i7Staples = "I7"
    /// R1: recipe id format and uniqueness; names non-blank and unique.
    case r1RecipeIdentity = "R1"
    /// R2: at least one meal type.
    case r2MealTypes = "R2"
    /// R3: minutes in range.
    case r3Minutes = "R3"
    /// R4: step count and step text.
    case r4Steps = "R4"
    /// R5: ingredient lines non-empty, known, unique, with quantity text.
    case r5Ingredients = "R5"
    /// R6: at least one required core-role ingredient.
    case r6CoreIngredient = "R6"
    /// R7: at most 8 required ingredients the user has to shop for.
    case r7RequiredCount = "R7"
    /// R8: flavours non-empty; mild never with spicy.
    case r8Flavours = "R8"
    /// R9: image asset path format and existence.
    case r9ImageAsset = "R9"
    /// R10: dish type agrees with base.
    case r10Base = "R10"
    /// R11: protein tag agrees with the ingredient list.
    case r11Protein = "R11"
    /// Catalogue totals (recipe and ingredient counts).
    case coverageTotals = "C-totals"
    /// Recipes per meal type.
    case coverageMealTypes = "C-meals"
    /// Recipes per region.
    case coverageRegions = "C-regions"
    /// Recipes per dish type.
    case coverageDishTypes = "C-dishTypes"
    /// Recipes per base, and maximum share of any one base.
    case coverageBases = "C-bases"
    /// Share of each heaviness.
    case coverageHeaviness = "C-heaviness"
    /// Share of quick recipes.
    case coverageQuick = "C-quick"
    /// Non-veg share, paneer and dal/legume counts.
    case coverageProtein = "C-protein"

    /// Short rule id as written in the seed guide, e.g. `R5`.
    public var rule: String { rawValue }
}

/// One broken seed-data rule, found by ``SeedValidator``.
///
/// There are no warnings: anything reported here fails the seed tests.
/// Intentional exceptions are listed explicitly in ``SeedRuleExemptions``.
/// Equality and hashing are value-based over every field.
public struct SeedIssue: Sendable, Hashable, CustomStringConvertible {
    /// The rule that is broken.
    public let code: SeedIssueCode

    /// Where, e.g. `recipes[aloo_gobi].ingredients[2]` or `ingredients`.
    public let location: String

    /// What is wrong, in plain language.
    public let message: String

    /// Creates an issue for `code` at `location`.
    ///
    /// - Parameters:
    ///   - code: The broken rule.
    ///   - location: Where the problem is.
    ///   - message: What is wrong.
    public init(_ code: SeedIssueCode, _ location: String, _ message: String) {
        self.code = code
        self.location = location
        self.message = message
    }

    /// `<rule> <location>: <message>`, e.g. `R3 recipes[x]: bad`.
    public var description: String { "\(code.rule) \(location): \(message)" }
}

/// Deliberate, reviewed exceptions to individual seed-data rules.
///
/// The validator has no "warning" level: a rule either holds or the seed
/// tests fail. When a rule is knowingly broken for a good reason, the
/// ingredient id is listed here, so the exception is explicit and shows up in
/// code review.
public struct SeedRuleExemptions: Sendable, Hashable {
    /// Ingredient ids exempt from I6 (sabzi/fruit → sabziwala, dairy →
    /// dairy). Coconut is a fruit, but households buy it from the kirana or a
    /// coconut seller as often as from the sabziwala.
    public let buyFrom: Set<String>

    /// Creates exemptions; the default is the one the shipped seed needs.
    ///
    /// - Parameter buyFrom: Ingredient ids exempt from I6; defaults to
    ///   `["coconut"]`.
    public init(buyFrom: Set<String> = ["coconut"]) {
        self.buyFrom = buyFrom
    }
}
