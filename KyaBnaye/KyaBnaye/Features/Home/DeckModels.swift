import Foundation
import KyaCore

/// What Home's deck area shows right now.
enum DeckContent: Equatable {
    /// Waiting for data or for the first deck build.
    case loading
    /// The card on top of the deck.
    case card(ScoredRecipe)
    /// Every card has been swiped: offer Shuffle and Switch mode.
    case endOfDeck
    /// Kitchen mode with nothing stocked: offer the Pantry or Craving mode instead.
    case emptyPantry
    /// Every recipe is hidden (or the book is empty): point to the recipe book.
    case noRecipes
    /// The data could not be read; the message explains, and Retry is offered.
    case failed(String)
}

extension DeckStore {
    /// The last swipe of this session, which Undo reverts.
    struct LastSwipe: Equatable {
        /// The logged swipe.
        let event: SwipeEvent
        /// The card it removed.
        let card: ScoredRecipe
    }
}

/// One row of the Today's picks tray.
struct PickRow: Identifiable, Equatable {
    /// The pick, derived from the swipe log.
    let pick: TodaysPick
    /// The picked recipe.
    let recipe: Recipe
    /// Distinct required ingredients not at home right now.
    let missingCount: Int

    /// The recipe id (one row per recipe).
    var id: String { recipe.id }

    /// One row per pick whose recipe still exists, in pick order.
    ///
    /// - Parameters:
    ///   - picks: Today's picks, newest first.
    ///   - recipes: Every stored recipe.
    ///   - ingredientsById: The catalog, keyed by id.
    ///   - pantry: Pantry records keyed by ingredient id.
    /// - Returns: The tray rows.
    static func rows(
        for picks: [TodaysPick], recipes: [Recipe], ingredientsById: [String: Ingredient],
        pantry: [String: PantryItem]
    ) -> [PickRow] {
        let recipesById = Dictionary(recipes.map { ($0.id, $0) }) { _, last in last }
        return picks.compactMap { pick in
            recipesById[pick.recipeId].map { recipe in
                PickRow(
                    pick: pick, recipe: recipe,
                    missingCount: RecipeCookability.evaluate(
                        recipe, ingredientsById: ingredientsById, pantry: pantry
                    ).missingCount)
            }
        }
    }

    static func == (lhs: PickRow, rhs: PickRow) -> Bool {
        lhs.pick == rhs.pick && lhs.recipe.isIdentical(to: rhs.recipe)
            && lhs.missingCount == rhs.missingCount
    }
}

/// Everything one deck build reads, as a `Sendable` value so the build can run off the main
/// actor. ``build()`` is a pure function of these fields.
struct DeckRequest: Sendable {
    /// Every stored recipe, in repository (id) order, which is the builder's tie-break order.
    let recipes: [Recipe]
    /// The pantry.
    let pantry: [PantryItem]
    /// The ingredient catalog.
    let catalog: [Ingredient]
    /// The full swipe log.
    let events: [SwipeEvent]
    /// The cooking history.
    let mealLogs: [MealLog]
    /// The reference instant.
    let now: Date
    /// Decides dates, weekdays and hours.
    let calendar: Calendar
    /// The meal slot Kitchen mode filters by.
    let mealType: MealType
    /// Which ranking strategy to use.
    let mode: SwipeMode
    /// Drives the Craving explore shuffle.
    let seed: Int
    /// The scoring weights (deck size ≤ 20 by default).
    var config = ScoringConfig()

    /// Builds the deck with `KyaCore`'s ``RankingContext`` and ``DeckBuilder``: exactly the
    /// `KyaCore` golden deck for this data. A hidden recipe or an active "Never show" swipe
    /// excludes a dish; "Unhide" clears both (``RecipeUnhide``), so no special case is
    /// needed here.
    ///
    /// - Returns: At most ``ScoringConfig/deckSize`` cards, top card first.
    func build() -> [ScoredRecipe] {
        let context = RankingContext.build(
            allRecipes: recipes, pantry: pantry, catalog: catalog, events: events,
            mealLogs: mealLogs, now: now, config: config, currentMealType: mealType,
            calendar: calendar)
        let builder = DeckBuilder()
        return switch mode {
        case .kitchen:
            builder.build(
                candidates: recipes, context: context, strategy: KitchenRanker(), seed: seed)
        case .craving:
            builder.build(
                candidates: recipes, context: context, strategy: CravingRanker(), seed: seed)
        }
    }
}

/// The store's copy of the append-only swipe log.
///
/// Keeps this store's just-written events that a snapshot doesn't show yet: a snapshot
/// emitted before a write can arrive after it, and would otherwise briefly resurrect an
/// undone pick. The log is append-only, so a union by id is always correct; the grace period
/// only stops a wiped store (erase all, restore) from keeping stale local events.
struct SwipeLogMirror {
    /// The log as this store knows it.
    private(set) var events: [SwipeEvent] = []
    private var unconfirmed: [SwipeEvent] = []

    /// How long a written event may be missing from snapshots before it is dropped.
    static let writeGrace: TimeInterval = 10

    /// Records an event this store has just written.
    mutating func record(_ event: SwipeEvent) {
        unconfirmed.append(event)
        if !events.contains(where: { $0.id == event.id }) { events.append(event) }
    }

    /// Takes a repository snapshot, keeping recent unconfirmed writes.
    mutating func merge(_ snapshot: [SwipeEvent], now: Date) {
        let storedIds = Set(snapshot.map(\.id))
        unconfirmed.removeAll {
            storedIds.contains($0.id) || abs(now.timeIntervalSince($0.at)) > Self.writeGrace
        }
        events = snapshot + unconfirmed
    }
}

extension ScoredRecipe {
    /// Required ingredients the recipe needs, for "Have X of Y ingredients".
    var requiredCount: Int { recipe.requiredIngredients.count }

    /// Required ingredients available now, for "Have X of Y ingredients".
    var haveCount: Int { max(requiredCount - missingIngredientIds.count, 0) }
}
