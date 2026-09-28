import Foundation
import KyaCore
import Testing

@testable import KyaBnaye

@Suite("DeckStore")
@MainActor
struct DeckStoreTests {
    private typealias F = DeckTestFixtures

    /// A store over `repositories` with a movable clock, sequential ids and seeds 101, 102...
    private func makeStore(
        _ repositories: RepositorySet, clock: DeckTestClock = DeckTestClock(),
        makeId: (() -> String)? = nil
    ) -> DeckStore {
        var seed = 100
        return DeckStore(
            repositories: repositories, now: { clock.now }, calendar: { F.calendar },
            makeId: makeId ?? RecipeTestFixtures.sequentialIds(),
            makeSeed: {
                seed += 1
                return seed
            })
    }

    /// Starts observing and waits for the first deck; returns the observing task.
    private func start(_ store: DeckStore) async -> Task<Void, Never> {
        let task = Task { await store.observe() }
        await recipesWaitUntil { store.phase == .loaded && !store.isBuilding }
        return task
    }

    private func ids(_ store: DeckStore) -> [String] { store.cards.map(\.recipe.id) }

    // MARK: Modes and goldens

    @Test("Kitchen is the mode on every launch, even after the last session used Craving")
    func kitchenByDefault() async throws {
        let repositories = try await F.repositories()
        let first = makeStore(repositories)
        let task = await start(first)
        await first.setMode(.craving)
        #expect(first.mode == .craving)
        task.cancel()

        let relaunched = makeStore(repositories)
        #expect(relaunched.mode == .kitchen)
    }

    @Test("the Kitchen deck matches KyaCore golden K2 (top 3, tiers, score)")
    func matchesKitchenGolden() async throws {
        let store = makeStore(try await F.repositories())
        let task = await start(store)
        defer { task.cancel() }

        #expect(store.mealType == .dinner)
        #expect(ids(store) == ["aloo_matar", "dal_tadka", "jeera_rice"])
        #expect(store.cards.map(\.tier) == [.readyNow, .missing1, .missing1])
        #expect(abs((store.cards.first?.score ?? 0) - 0.65) < 1e-9)
        #expect(store.content == .card(try #require(store.cards.first)))
    }

    @Test("the Craving deck matches KyaCore golden C2 (top 3)")
    func matchesCravingGolden() async throws {
        let history = [("masala_dosa", 1.0), ("upma", 2.0), ("lemon_rice", 3.0)].map {
            SwipeEvent(
                id: "right-\($0.0)", recipeId: $0.0, action: .right, mode: .craving,
                at: F.weekdayDinner.addingTimeInterval(-$0.1 * 86_400), deckSeed: 1)
        }
        let repositories = try await F.repositories(
            pantry: ["poha", "onion", "green_chilli"], events: history)
        let store = makeStore(repositories)
        let task = await start(store)
        defer { task.cancel() }

        await store.setMode(.craving)

        #expect(Array(ids(store).prefix(3)) == ["upma", "poha", "lemon_rice"])
        #expect(store.cards.allSatisfy { $0.tier == nil })
    }

    @Test("switching to Craving rebuilds the deck exactly as KyaCore would, with the same seed")
    func cravingMatchesCore() async throws {
        let store = makeStore(try await F.repositories())
        let task = await start(store)
        defer { task.cancel() }

        await store.setMode(.craving)

        // The store offers candidates in repository order (by id), the builder's tie-break.
        let candidates = F.recipes.sorted { $0.id < $1.id }
        let context = RankingContext.build(
            allRecipes: candidates, pantry: F.stocked(F.k2Pantry), catalog: F.catalog,
            events: [], mealLogs: [], now: F.weekdayDinner, currentMealType: .dinner,
            calendar: F.calendar)
        let expected = DeckBuilder().build(
            candidates: candidates, context: context, strategy: CravingRanker(),
            seed: store.deckSeed)
        #expect(ids(store) == expected.map(\.recipe.id))
        #expect(store.cards.count == F.recipes.count)
        #expect(store.cards.allSatisfy { $0.tier == nil && $0.isExplore })  // cold start
    }

    @Test("the meal-slot override rebuilds Kitchen for that meal")
    func mealOverride() async throws {
        let store = makeStore(try await F.repositories(pantry: ["poha", "onion", "green_chilli"]))
        let task = await start(store)
        defer { task.cancel() }

        await store.setMealType(.breakfast)

        #expect(store.mealType == .breakfast)
        #expect(ids(store).first == "poha")
        await store.setMealType(nil)
        #expect(store.mealType == .dinner)
    }

    // MARK: Swipes

    @Test("swipe right appends a right event, opens the pick sheet and adds a pick")
    func swipeRight() async throws {
        let repositories = try await F.repositories()
        let store = makeStore(repositories)
        let task = await start(store)
        defer { task.cancel() }

        await store.swipe(.right)

        let events = try await repositories.swipeEvents.all()
        #expect(
            events == [
                SwipeEvent(
                    id: "id1", recipeId: "aloo_matar", action: .right, mode: .kitchen,
                    at: F.weekdayDinner, deckSeed: 101)
            ])
        #expect(store.pickedCard?.recipe.id == "aloo_matar")
        #expect(ids(store) == ["dal_tadka", "jeera_rice"])
        #expect(store.picks.map(\.recipe.id) == ["aloo_matar"])
        #expect(store.picks.first?.missingCount == 0)
        #expect(store.canUndo)
    }

    @Test("swipe left appends a left event in the current mode")
    func swipeLeft() async throws {
        let repositories = try await F.repositories()
        let store = makeStore(repositories)
        let task = await start(store)
        defer { task.cancel() }
        await store.setMode(.craving)
        let top = try #require(store.cards.first)

        await store.swipe(.left)

        let event = try #require(try await repositories.swipeEvents.all().first)
        #expect(event.action == .left)
        #expect(event.mode == .craving)
        #expect(event.recipeId == top.recipe.id)
        #expect(store.pickedCard == nil)
        #expect(store.picks.isEmpty)
    }

    @Test("never show appends a never-show event, hides the recipe, and the next deck skips it")
    func neverShow() async throws {
        let repositories = try await F.repositories()
        let store = makeStore(repositories)
        let task = await start(store)
        defer { task.cancel() }

        await store.swipe(.neverShow)

        #expect(try await repositories.swipeEvents.all().map(\.action) == [.neverShow])
        #expect(try await repositories.recipes.recipe(withId: "aloo_matar")?.isHidden == true)
        await store.shuffle()
        #expect(!ids(store).contains("aloo_matar"))
        #expect(ids(store) == ["dal_tadka", "jeera_rice"])
    }

    @Test("undo appends an undo event for the last swipe and restores its card and pick")
    func undoRight() async throws {
        let repositories = try await F.repositories()
        let store = makeStore(repositories)
        let task = await start(store)
        defer { task.cancel() }
        await store.swipe(.right)

        await store.undo()

        let events = try await repositories.swipeEvents.all()
        #expect(events.map(\.action) == [.right, .undo])
        #expect(events.last?.undoesEventId == "id1")
        #expect(events.last?.recipeId == "aloo_matar")
        #expect(events.last?.deckSeed == 101)
        #expect(ids(store) == ["aloo_matar", "dal_tadka", "jeera_rice"])
        #expect(store.picks.isEmpty)
        #expect(store.pickedCard == nil)
        #expect(!store.canUndo)
        #expect(store.confirmation == "Aloo Matar is back")
    }

    @Test("undoing never-show unhides the recipe")
    func undoNeverShow() async throws {
        let repositories = try await F.repositories()
        let store = makeStore(repositories)
        let task = await start(store)
        defer { task.cancel() }
        await store.swipe(.neverShow)

        await store.undo()

        #expect(try await repositories.recipes.recipe(withId: "aloo_matar")?.isHidden == false)
        #expect(ids(store).first == "aloo_matar")
        // The rebuilds triggered by hiding and unhiding must not drop the restored card.
        try await Task.sleep(for: .milliseconds(200))
        await recipesWaitUntil { !store.isBuilding }
        #expect(ids(store) == ["aloo_matar", "dal_tadka", "jeera_rice"])
    }

    @Test("unhiding in the recipe book revokes the never-show, so the dish returns to the deck")
    func unhideReturnsToDeck() async throws {
        let repositories = try await F.repositories()
        let store = makeStore(repositories)
        let task = await start(store)
        defer { task.cancel() }
        await store.swipe(.neverShow)
        let recipes = RecipesStore(
            repositories: repositories, now: { F.weekdayDinner }, calendar: { F.calendar },
            makeId: { "unhide-1" })
        let hidden = try #require(try await repositories.recipes.recipe(withId: "aloo_matar"))

        await recipes.setHidden(false, for: hidden)

        let events = try await repositories.swipeEvents.all()
        #expect(events.map(\.action) == [.neverShow, .undo])
        #expect(events.last?.undoesEventId == events.first?.id)
        #expect(SwipeEvent.activeEvents(events).isEmpty)
        // The recipe and log snapshots reach the deck asynchronously; a new deck (the card
        // was swiped this session) shows the dish once they have.
        for _ in 0..<100 where !ids(store).contains("aloo_matar") {
            try await Task.sleep(for: .milliseconds(20))
            await store.shuffle()
        }
        #expect(ids(store).contains("aloo_matar"))
    }

    @Test("a swipe that can't be saved keeps the card and shows an error")
    func swipeFailure() async throws {
        let existing = SwipeEvent(
            id: "dup", recipeId: "poha", action: .left, mode: .kitchen,
            at: F.weekdayDinner.addingTimeInterval(-30 * 86_400), deckSeed: 1)
        let repositories = try await F.repositories(events: [existing])
        let store = makeStore(repositories, makeId: { "dup" })
        let task = await start(store)
        defer { task.cancel() }

        await store.swipe(.right)

        #expect(ids(store).first == "aloo_matar")
        #expect(store.actionError == "Couldn't save your choice for Aloo Matar. Please try again.")
        #expect(store.pickedCard == nil)
        #expect(try await repositories.swipeEvents.all() == [existing])
    }

    // MARK: Deck lifecycle

    @Test("shuffle changes the seed and starts a new session")
    func shuffleChangesSeed() async throws {
        let store = makeStore(try await F.repositories())
        let task = await start(store)
        defer { task.cancel() }
        let before = store.deckSeed
        await store.swipe(.left)

        await store.shuffle()

        #expect(store.deckSeed != before)
        #expect(!store.canUndo)
        #expect(ids(store) == ["dal_tadka", "jeera_rice"])  // left swipe hides for 3 days
    }

    @Test("swiping every card reaches the end of the deck")
    func endOfDeck() async throws {
        let store = makeStore(try await F.repositories())
        let task = await start(store)
        defer { task.cancel() }

        for _ in 0..<3 { await store.swipe(.left) }

        #expect(store.cards.isEmpty)
        #expect(store.content == .endOfDeck)
        #expect(store.canUndo)
    }

    @Test("Kitchen with nothing stocked shows the empty-pantry state; Craving still has cards")
    func emptyPantry() async throws {
        let store = makeStore(try await F.repositories(pantry: []))
        let task = await start(store)
        defer { task.cancel() }

        #expect(store.content == .emptyPantry)
        await store.setMode(.craving)
        #expect(store.cards.count == F.recipes.count)
        #expect(store.content == .card(try #require(store.cards.first)))
    }

    @Test("with every dish hidden, both modes show the no-recipes state; unhiding one recovers")
    func everyDishHidden() async throws {
        let repositories = try await F.repositories()
        for recipe in F.recipes {
            try await repositories.recipes.setHidden(true, forRecipeWithId: recipe.id)
        }
        let store = makeStore(repositories)
        let task = await start(store)
        defer { task.cancel() }

        #expect(store.content == .noRecipes)
        await store.setMode(.craving)
        #expect(store.content == .noRecipes)

        try await repositories.recipes.setHidden(false, forRecipeWithId: "aloo_matar")
        await recipesWaitUntil { store.cards.map(\.recipe.id) == ["aloo_matar"] }
        #expect(store.content == .card(try #require(store.cards.first)))
    }

    @Test("today's picks stay out of new decks")
    func picksExcluded() async throws {
        let store = makeStore(try await F.repositories())
        let task = await start(store)
        defer { task.cancel() }
        await store.swipe(.right)

        await store.shuffle()

        #expect(ids(store) == ["dal_tadka", "jeera_rice"])
        #expect(store.picks.map(\.recipe.id) == ["aloo_matar"])
    }

    @Test("a pantry change rebuilds behind the top card, which stays put")
    func pinnedRebuild() async throws {
        let repositories = try await F.repositories()
        let store = makeStore(repositories)
        let task = await start(store)
        defer { task.cancel() }
        await store.swipe(.left)  // top card is now dal_tadka
        #expect(ids(store) == ["dal_tadka", "jeera_rice"])

        try await repositories.pantry.setLevels(
            F.stocked(["toor_dal", "rice", "lemon", "curry_leaves"]))
        await recipesWaitUntil { store.cards.count > 2 && !store.isBuilding }

        #expect(ids(store).first == "dal_tadka")
        #expect(store.cards.first?.tier == .readyNow)  // refreshed from the rebuild
        #expect(!ids(store).contains("aloo_matar"))  // swiped this session
        #expect(ids(store).contains("lemon_rice"))
    }

    @Test("picks clear after midnight")
    func midnightRollover() async throws {
        let clock = DeckTestClock()
        let store = makeStore(try await F.repositories(), clock: clock)
        let task = await start(store)
        defer { task.cancel() }
        await store.swipe(.right)
        #expect(store.picks.count == 1)

        clock.now = F.calendar.date(byAdding: .hour, value: 6, to: F.weekdayDinner) ?? .now
        await store.refreshForNewDay()

        #expect(store.picks.isEmpty)
        #expect(store.mealType == .dinner)  // 01:00 is still the dinner slot
    }

    @Test("add missing puts only the missing ingredients on the list, once")
    func addMissing() async throws {
        let repositories = try await F.repositories()
        let store = makeStore(repositories)
        let task = await start(store)
        defer { task.cancel() }
        let dal = try #require(F.recipes.first { $0.id == "dal_tadka" })

        #expect(await store.addMissingToShoppingList(dal) == 1)
        #expect(await store.addMissingToShoppingList(dal) == 0)

        let items = try await repositories.shopping.all()
        #expect(items.map(\.ingredientId) == ["toor_dal"])
        #expect(items.first?.reason == .recipe)
        #expect(store.confirmation == "Everything missing is already on your list")
    }
}
