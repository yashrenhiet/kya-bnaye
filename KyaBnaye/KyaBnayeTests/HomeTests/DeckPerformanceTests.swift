import Foundation
import KyaCore
import Testing

@testable import KyaBnaye

/// Times one deck build over the real bundled seed (80 recipes, 224 ingredients) with a
/// month of history. The build runs off the main actor in the app (``DeckStore``), because
/// on an older iPhone it can exceed a 16 ms frame; this guards against it growing into a
/// visible delay even there.
@Suite("Deck build performance")
struct DeckPerformanceTests {
    @Test("a Kitchen or Craving deck over the full seed builds well within budget")
    func buildTime() async throws {
        let repositories = try SwiftDataStore.inMemory().repositories
        _ = try await SeedLoader.bundled(in: .main).apply(to: repositories)
        let recipes = try await repositories.recipes.all()
        let catalog = try await repositories.ingredients.all()
        #expect(recipes.count >= 80)

        let now = DeckTestFixtures.weekdayDinner
        let pantry = ["onion", "tomato", "potato", "ginger", "garlic", "green_chilli", "curd"]
            .map { PantryItem(ingredientId: $0, level: .plenty, updatedAt: now) }
        let events = recipes.prefix(30).enumerated().map { index, recipe in
            SwipeEvent(
                id: "e\(index)", recipeId: recipe.id, action: index % 3 == 0 ? .left : .right,
                mode: .craving, at: now.addingTimeInterval(Double(-index) * 3_600), deckSeed: 1)
        }
        let logs = recipes.prefix(20).enumerated().map { index, recipe in
            MealLog(
                id: "m\(index)", recipeId: recipe.id, mealType: .dinner,
                cookedAt: now.addingTimeInterval(Double(-index) * 86_400))
        }

        for mode in SwipeMode.allCases {
            let request = DeckRequest(
                recipes: recipes, pantry: pantry, catalog: catalog, events: events,
                mealLogs: logs, now: now, calendar: DeckTestFixtures.calendar, mealType: .dinner,
                mode: mode, seed: 7)
            let clock = ContinuousClock()
            var durations: [Duration] = []
            for _ in 0..<5 {
                durations.append(clock.measure { _ = request.build() })
            }
            let median = durations.sorted()[durations.count / 2]
            #expect(median < .milliseconds(100), "\(mode.rawValue) deck took \(median)")
        }
    }
}
