/// Checks a decoded ``SeedBundle`` against the seed-data rules in
/// `docs/design/SEED_GUIDE.md` section 7: ingredient rules I1–I7, recipe
/// rules R1–R11 and, when targets are given, catalogue coverage.
///
/// I8 (rows sorted by id within each fragment) needs fragment boundaries,
/// which a ``SeedBundle`` no longer has, so the seed-asset test checks it.
///
/// Pure and I/O-free: whether an image file exists is answered by an injected
/// closure. Issues are reported in a deterministic order that replicates the
/// Dart oracle: ingredients in bundle order (I1, I2, I4, I5, I6, I7 per
/// ingredient), then alias collisions (I3) and the staple count (I7), then
/// every recipe in bundle order, then coverage.
public struct SeedValidator: Sendable {
    /// Format shared by ingredient and recipe ids, as a regular expression.
    public static let idPattern = "^[a-z][a-z0-9_]*$"

    /// Prefix reserved for ingredients users create at runtime.
    public static let userIdPrefix = "user_"

    /// Allowed number of staple-role ingredients (I7), inclusive.
    public static let staplesRange = 12...25

    /// Allowed `shelfLifeDays` (I5), inclusive.
    public static let shelfLifeRange = 1...3650

    private static let perishableCategories: Set<IngredientCategory> = [.sabzi, .fruit, .dairy]
    private static let perishableIds: Set<String> = ["eggs", "chicken", "mutton", "fish", "prawns"]
    /// Categories that may hold staples, in the order the I7 message lists them.
    private static let stapleCategories: [IngredientCategory] = [
        .masala, .oilGhee, .grains, .other,
    ]

    /// Creates a validator. Stateless.
    public init() {}

    /// Whether `id` matches ``idPattern`` (ASCII `a`–`z` first, then `a`–`z`,
    /// `0`–`9` or `_`).
    ///
    /// - Parameter id: A candidate ingredient or recipe id.
    /// - Returns: `true` for a well-formed id.
    public static func isValidId(_ id: String) -> Bool {
        guard let first = id.utf8.first, isLowercaseLetter(first) else { return false }
        return id.utf8.dropFirst().allSatisfy { byte in
            isLowercaseLetter(byte) || (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
                || byte == UInt8(ascii: "_")
        }
    }

    /// Returns every broken rule in `bundle`; empty means valid. Never throws
    /// for bad data and never stops at the first issue.
    ///
    /// - Parameters:
    ///   - bundle: The decoded seed data.
    ///   - assetExists: Whether an image path relative to `seed/` (such as
    ///     `images/poha.webp`) is bundled (R9). Only called for recipes whose
    ///     `imageAsset` is non-`nil` and correctly named.
    ///   - coverage: Catalogue coverage targets; coverage is only checked
    ///     when given.
    ///   - exemptions: Reviewed rule exceptions.
    /// - Returns: The issues, in the order described on the type.
    public func validate(
        _ bundle: SeedBundle,
        assetExists: (String) -> Bool,
        coverage: SeedCoverageTargets? = nil,
        exemptions: SeedRuleExemptions = SeedRuleExemptions()
    ) -> [SeedIssue] {
        var issues = Self.ingredientIssues(bundle.ingredients, exemptions: exemptions)
        issues += SeedRecipeRules.check(bundle, assetExists: assetExists)
        if let coverage {
            issues += SeedCoverageRules.check(bundle, coverage)
        }
        return issues
    }

    // MARK: Ingredient rules

    private static func ingredientIssues(
        _ ingredients: [Ingredient], exemptions: SeedRuleExemptions
    ) -> [SeedIssue] {
        var issues: [SeedIssue] = []
        var ids = Set<String>()
        var nameOwners: [String: String] = [:]
        for ingredient in ingredients {
            func issue(_ code: SeedIssueCode, _ field: String, _ message: String) {
                issues.append(SeedIssue(code, "ingredients[\(ingredient.id)]\(field)", message))
            }
            if !isValidId(ingredient.id) {
                issue(.i1IngredientId, "", "id must match \(idPattern)")
            } else if ingredient.id.hasPrefix(userIdPrefix) {
                issue(
                    .i1IngredientId, "",
                    "the \"\(userIdPrefix)\" id prefix is reserved for user ingredients")
            }
            if !ids.insert(ingredient.id).inserted {
                issue(.i1IngredientId, "", "duplicate id")
            }
            for message in nameProblems(ingredient, owners: &nameOwners) {
                issue(.i2IngredientName, ".name", message)
            }
            for (index, alias) in ingredient.aliases.enumerated() {
                let normalised = IngredientNormalizer.normalise(alias)
                if normalised.isEmpty {
                    issue(.i4AliasFormat, ".aliases[\(index)]", "blank alias")
                } else if alias != normalised {
                    issue(
                        .i4AliasFormat, ".aliases[\(index)]",
                        "alias \"\(alias)\" must be lowercase, trimmed and single-spaced "
                            + "(\"\(normalised)\")")
                }
            }
            if let message = shelfLifeProblem(ingredient) {
                issue(.i5ShelfLife, ".shelfLifeDays", message)
            }
            if let expected = expectedVendor(ingredient.category),
                ingredient.buyFrom != expected, !exemptions.buyFrom.contains(ingredient.id)
            {
                issue(
                    .i6BuyFrom, ".buyFrom",
                    "\(ingredient.category.rawValue) must be bought from \(expected.rawValue), "
                        + "not \(ingredient.buyFrom.rawValue)")
            }
            if ingredient.role == .staple, !stapleCategories.contains(ingredient.category) {
                let allowed = stapleCategories.map(\.rawValue).joined(separator: ", ")
                issue(
                    .i7Staples, ".role",
                    "a \(ingredient.category.rawValue) ingredient cannot be a staple "
                        + "(allowed: \(allowed))")
            }
        }
        issues += SeedAliasCollisions.issues(ingredients)
        let staples = ingredients.count { $0.role == .staple }
        if !staplesRange.contains(staples) {
            issues.append(
                SeedIssue(
                    .i7Staples, "ingredients",
                    "\(staples) staples; expected "
                        + "\(staplesRange.lowerBound)–\(staplesRange.upperBound)"))
        }
        return issues
    }

    /// I2: the problems with `ingredient`'s name, registering it in `owners`.
    private static func nameProblems(
        _ ingredient: Ingredient, owners: inout [String: String]
    ) -> [String] {
        let trimmed = DartCompatibleText.trim(ingredient.name)
        if trimmed.isEmpty { return ["name is blank"] }
        var problems: [String] = []
        if ingredient.name != trimmed { problems.append("name has surrounding whitespace") }
        let key = IngredientNormalizer.normalise(ingredient.name)
        let owner = owners[key, default: ingredient.id]
        owners[key] = owner
        if owner != ingredient.id {
            problems.append("name \"\(ingredient.name)\" is also used by \(owner)")
        }
        return problems
    }

    /// I5: the problem with `ingredient`'s shelf life, if any.
    private static func shelfLifeProblem(_ ingredient: Ingredient) -> String? {
        guard let days = ingredient.shelfLifeDays else {
            let perishable =
                perishableCategories.contains(ingredient.category)
                || perishableIds.contains(ingredient.id)
            return perishable ? "required for a perishable ingredient" : nil
        }
        guard !shelfLifeRange.contains(days) else { return nil }
        return "\(days) is outside \(shelfLifeRange.lowerBound)–\(shelfLifeRange.upperBound)"
    }

    /// I6: the vendor `category` must be bought from, or `nil` if any.
    private static func expectedVendor(_ category: IngredientCategory) -> BuyFrom? {
        switch category {
        case .sabzi, .fruit: .sabziwala
        case .dairy: .dairy
        default: nil
        }
    }

    private static func isLowercaseLetter(_ byte: UInt8) -> Bool {
        (UInt8(ascii: "a")...UInt8(ascii: "z")).contains(byte)
    }
}
