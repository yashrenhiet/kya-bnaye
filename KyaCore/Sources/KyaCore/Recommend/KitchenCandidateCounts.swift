import Foundation

/// How many of `recipes` Kitchen mode would offer for each meal type, for a
/// household that has exactly `atHome` (ingredient ids, all at
/// ``StockLevel/plenty``, no expiry) plus the always-assumed staples.
///
/// Used to prove a catalogue (e.g. the bundled seed) gives a first-run user a
/// real deck: there is no swipe or cooking history, so only pantry coverage
/// decides. Unknown ids in `atHome` are harmless. `now` only feeds
/// ``RankingContext``; with no history it does not change which recipes
/// qualify.
///
/// - Parameters:
///   - recipes: The candidate recipes (also fixes rarity frequencies).
///   - catalog: Every known ingredient.
///   - atHome: Ingredient ids stocked at ``StockLevel/plenty``.
///   - now: The reference instant.
///   - calendar: Decides calendar dates; defaults to
///     ``Foundation/Calendar/kyaDefault``.
/// - Returns: A count for every ``MealType`` (zero when none qualify).
public func kitchenCandidateCounts(
    recipes: [Recipe],
    catalog: [Ingredient],
    atHome: Set<String>,
    now: Date,
    calendar: Calendar = .kyaDefault
) -> [MealType: Int] {
    let pantry = atHome.sorted().map {
        PantryItem(ingredientId: $0, level: .plenty, updatedAt: now)
    }
    let ranker = KitchenRanker()
    var counts: [MealType: Int] = [:]
    for meal in MealType.allCases {
        let context = RankingContext.build(
            allRecipes: recipes, pantry: pantry, catalog: catalog, events: [], mealLogs: [],
            now: now, currentMealType: meal, calendar: calendar)
        counts[meal] = recipes.filter { ranker.score($0, in: context) != nil }.count
    }
    return counts
}
