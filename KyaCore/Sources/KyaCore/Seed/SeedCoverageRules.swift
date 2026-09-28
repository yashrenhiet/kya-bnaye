import Foundation

/// Coverage checks for ``SeedValidator``. Internal.
///
/// Issues are reported in a fixed order: totals, meal types, regions, dish
/// types, bases, heaviness, quick share, non-veg share, paneer, dal/legume.
/// Meal types, dish types, bases and heaviness follow enum declaration order;
/// regions follow the order of the default targets (north, punjabi, south,
/// east, west, gujarati, street, indoChinese, continental). The Dart oracle
/// iterated the caller's map literal, which a Swift dictionary cannot
/// preserve; for the default targets the order is identical.
enum SeedCoverageRules {
    private static let nonVeg: Set<Protein> = [.chicken, .mutton, .fish, .egg]

    private static let regionOrder: [Region] = [
        .north, .punjabi, .south, .east, .west, .gujarati, .street, .indoChinese, .continental,
    ]

    /// Every target in `targets` that `bundle` misses.
    static func check(_ bundle: SeedBundle, _ targets: SeedCoverageTargets) -> [SeedIssue] {
        var issues: [SeedIssue] = []
        func report(_ issue: SeedIssue) { issues.append(issue) }
        let recipes = bundle.recipes
        let total = recipes.count
        func share(_ count: Int) -> Double { total == 0 ? 0 : Double(count) / Double(total) }
        func count(_ test: (Recipe) -> Bool) -> Int { recipes.count(where: test) }
        func range(_ code: SeedIssueCode, _ what: String, _ n: Int, _ min: Int, _ max: Int) {
            if n < min || n > max {
                report(SeedIssue(code, what, "\(n) \(what); expected \(min)–\(max)"))
            }
        }
        func atLeast(_ code: SeedIssueCode, _ what: String, _ n: Int, _ min: Int) {
            if n < min {
                let noun = n == 1 ? "recipe" : "recipes"
                report(SeedIssue(code, what, "\(n) \(noun); expected at least \(min)"))
            }
        }
        func minShare(_ code: SeedIssueCode, _ what: String, _ n: Int, _ min: Double) {
            if share(n) < min {
                report(
                    SeedIssue(
                        code, what,
                        "\(percent(share(n))) of recipes; expected at least \(percent(min))"))
            }
        }

        range(.coverageTotals, "recipes", total, targets.minRecipes, targets.maxRecipes)
        range(
            .coverageTotals, "ingredients", bundle.ingredients.count, targets.minIngredients,
            targets.maxIngredients)
        for meal in MealType.allCases {
            guard let min = targets.minRecipesPerMealType[meal] else { continue }
            atLeast(
                .coverageMealTypes, "mealTypes.\(meal.rawValue)",
                count { $0.mealTypes.contains(meal) }, min)
        }
        for region in regionOrder {
            guard let min = targets.minRecipesPerRegion[region] else { continue }
            atLeast(
                .coverageRegions, "region.\(region.rawValue)",
                count { $0.tags.region == region }, min)
        }
        for type in DishType.allCases where !targets.dishTypeExemptions.contains(type) {
            atLeast(
                .coverageDishTypes, "dishType.\(type.rawValue)",
                count { $0.tags.dishType == type }, targets.minRecipesPerDishType)
        }
        for base in DishBase.allCases {
            let n = count { $0.base == base }
            atLeast(
                .coverageBases, "base.\(base.rawValue)", n, targets.minRecipesPerBase[base] ?? 0)
            if share(n) > targets.maxBaseShare {
                report(
                    SeedIssue(
                        .coverageBases, "base.\(base.rawValue)",
                        "\(percent(share(n))) of recipes; at most \(percent(targets.maxBaseShare))"
                    ))
            }
        }
        for heaviness in Heaviness.allCases {
            minShare(
                .coverageHeaviness, "heaviness.\(heaviness.rawValue)",
                count { $0.tags.heaviness == heaviness }, targets.minHeavinessShare)
        }
        minShare(
            .coverageQuick, "quick (≤ \(targets.quickMaxMinutes) min)",
            count { $0.minutes <= targets.quickMaxMinutes }, targets.minQuickShare)
        let nonVegShare = share(count { nonVeg.contains($0.tags.protein) })
        if nonVegShare < targets.minNonVegShare || nonVegShare > targets.maxNonVegShare {
            report(
                SeedIssue(
                    .coverageProtein, "protein.nonVeg",
                    "\(percent(nonVegShare)) of recipes; expected "
                        + "\(percent(targets.minNonVegShare))–\(percent(targets.maxNonVegShare))"))
        }
        atLeast(
            .coverageProtein, "protein.paneer", count { $0.tags.protein == .paneer },
            targets.minPaneerRecipes)
        atLeast(
            .coverageProtein, "protein.dalLegume", count { $0.tags.protein == .dalLegume },
            targets.minDalLegumeRecipes)
        return issues
    }

    /// Dart's `'${(fraction * 100).toStringAsFixed(1)}%'`, e.g. `40.0%`.
    /// `String(format:)` without a locale always uses `.` as the separator.
    static func percent(_ fraction: Double) -> String {
        String(format: "%.1f%%", fraction * 100)
    }
}
