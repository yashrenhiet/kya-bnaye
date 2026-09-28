import Foundation
import KyaCore
import Observation

/// State and actions for Home's swipe deck (F4, F4b) and the Today's picks tray (F4c).
///
/// **Modes.** Kitchen is the default every time the store is created (decision D5); the mode
/// is deliberately never persisted. The meal slot follows the clock unless overridden.
///
/// **Recompute policy.** A deck is built from one snapshot of the data, off the main actor
/// (``DeckRequest``). Afterwards:
/// - The user's own swipes never rebuild the deck. The swiped card simply leaves, so the
///   cards behind it don't reshuffle under the user as the taste profile shifts.
/// - A change to recipes, pantry, catalog or cooking history (for example "Used up
///   anything?" after "I made this" from the tray, or an edit in another tab) rebuilds the
///   deck, but the card on top stays pinned (``DeckRefresh``), so a card mid-drag is never
///   swapped out. Only the cards behind it change.
/// - Mode switch, Shuffle (a new seed) and a meal-slot change start a new deck session.
/// - Builds are numbered; a result that finishes after a newer build started is dropped.
///
/// Cards already swiped this session and dishes already in Today's picks never reappear in
/// the deck. Every swipe is appended to the swipe log (ADR 008); Undo appends an undo event
/// for the last swipe of the session and puts its card back on top.
@Observable
@MainActor
final class DeckStore {
    /// Where the data is in loading.
    enum Phase: Equatable {
        /// Waiting for the first snapshots.
        case loading
        /// Every source has delivered.
        case loaded
        /// A source failed; the message is user-facing.
        case failed(String)
    }

    /// The loading phase.
    private(set) var phase: Phase = .loading
    /// The active ranking mode; Kitchen on every launch.
    private(set) var mode: SwipeMode = .kitchen
    /// The user's meal-slot choice, or `nil` to follow the clock.
    private(set) var mealTypeOverride: MealType?
    /// The meal slot the current deck was built for.
    private(set) var mealType: MealType
    // `cards`, `isWriting` and `lastSwipe` have an internal (not private) setter: the swipe
    // actions in `DeckStore+Swipes.swift` mutate them directly.
    /// The remaining cards, top card first.
    var cards: [ScoredRecipe] = []
    /// The seed the current deck was built with; Shuffle replaces it.
    private(set) var deckSeed: Int
    /// Whether a deck build is running.
    private(set) var isBuilding = false
    /// Whether a swipe or undo is being written, so controls can be disabled.
    var isWriting = false
    /// The swipe Undo would revert.
    var lastSwipe: LastSwipe?
    /// Today's picks, newest first.
    private(set) var picks: [PickRow] = []
    /// Whether any pantry item is in stock (Plenty or Low).
    private(set) var hasStockedPantry = false
    /// Whether the recipe book has any dish that is not hidden.
    private(set) var hasVisibleRecipes = true
    /// The card just swiped right, driving the pick sheet.
    var pickedCard: ScoredRecipe?
    /// A failed action, shown as an alert until dismissed.
    var actionError: String?
    /// A short confirmation, shown briefly and announced to VoiceOver.
    var confirmation: String?

    @ObservationIgnored private var recipes: [Recipe] = []
    @ObservationIgnored private var pantry: [PantryItem] = []
    @ObservationIgnored private var catalog: [Ingredient] = []
    @ObservationIgnored private var mealLogs: [MealLog] = []
    // `ingredientsById` and `pantryById` are also read by the shopping-list actions in
    // `DeckStore+Shopping.swift`; `log` and `sessionSwipedIds` are also written by the swipe
    // actions in `DeckStore+Swipes.swift`. All four are internal rather than file-private.
    @ObservationIgnored var ingredientsById: [String: Ingredient] = [:]
    @ObservationIgnored var pantryById: [String: PantryItem] = [:]
    @ObservationIgnored var log = SwipeLogMirror()
    @ObservationIgnored var sessionSwipedIds: Set<String> = []
    @ObservationIgnored private var pickedRecipeIds: Set<String> = []
    @ObservationIgnored private var loaded: Set<Source> = []
    @ObservationIgnored private var buildGeneration = 0
    /// Recipe ids with an "Add missing to shopping list" write in flight, so a double tap
    /// (Home's pick sheet and Today's picks tray both offer it) can't add duplicates.
    @ObservationIgnored var addingMissingFor: Set<String> = []

    // `repositories`, `now`, `calendar` and `makeId` are also used by
    // `DeckStore+Shopping.swift` and `DeckStore+Scheduling.swift`.
    @ObservationIgnored let repositories: RepositorySet
    @ObservationIgnored let now: () -> Date
    @ObservationIgnored let calendar: () -> Calendar
    @ObservationIgnored let makeId: () -> String
    @ObservationIgnored private let makeSeed: () -> Int

    private enum Source: CaseIterable { case recipes, pantry, catalog, events, history }

    /// Creates the store in Kitchen mode with a fresh seed.
    ///
    /// - Parameters:
    ///   - repositories: The ports to read and write through.
    ///   - now: The clock.
    ///   - calendar: Decides "today", the meal slot and expiry days.
    ///   - makeId: New swipe event and shopping item ids.
    ///   - makeSeed: New deck seeds.
    init(
        repositories: RepositorySet,
        now: @escaping () -> Date,
        calendar: @escaping () -> Calendar,
        makeId: @escaping () -> String = { UUID().uuidString },
        makeSeed: @escaping () -> Int = { Int.random(in: 1...Int(Int32.max)) }
    ) {
        self.repositories = repositories
        self.now = now
        self.calendar = calendar
        self.makeId = makeId
        self.makeSeed = makeSeed
        deckSeed = makeSeed()
        mealType = MealHistory.currentMealType(now: now(), calendar: calendar())
    }

    // MARK: Derived state

    /// What the deck area shows.
    var content: DeckContent {
        switch phase {
        case .loading: return .loading
        case .failed(let message): return .failed(message)
        case .loaded:
            if !hasVisibleRecipes { return .noRecipes }
            if mode == .kitchen && !hasStockedPantry { return .emptyPantry }
            if let top = cards.first { return .card(top) }
            return isBuilding ? .loading : .endOfDeck
        }
    }

    /// Whether Undo is available.
    var canUndo: Bool { lastSwipe != nil && !isWriting }

    /// Catalog names for ingredient ids, in the given order (the id if unknown).
    func ingredientNames(_ ids: [String]) -> [String] {
        ids.map { ingredientsById[$0]?.name ?? $0 }
    }

    // MARK: Loading

    /// Follows every source the deck depends on, and rolls Today's picks over at midnight,
    /// until cancelled. Restarting (Home reappears after History, Settings or a recipe was
    /// pushed over it) keeps the cards on screen, top card pinned; only a failed load
    /// starts over from the loading state.
    func observe() async {
        if case .failed = phase { phase = .loading }
        loaded = []
        do {
            // A plain tuple of `async let` awaits its members left to right and never
            // short-circuits, so a failure in `pantry` (say) would stay unnoticed forever
            // behind the still-running, infinite `recipes` stream. Every child here runs
            // until cancelled (`follow` loops its stream, `followDays` loops its sleep), so
            // none of them is ever expected to return normally: the first one to finish at
            // all (by throwing) is a failure, and `group.next()` reports it as soon as it
            // happens rather than waiting for the others to notice cancellation too.
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await self.follow(self.repositories.recipes.watchAll(), .recipes) {
                        self.recipes = $0
                        self.hasVisibleRecipes = $0.contains { !$0.isHidden }
                    }
                }
                group.addTask {
                    try await self.follow(self.repositories.pantry.watchAll(), .pantry) {
                        self.pantry = $0
                        self.pantryById = Dictionary($0.map { ($0.ingredientId, $0) }) {
                            _, last in last
                        }
                        self.hasStockedPantry = $0.contains { $0.level.isAvailable }
                    }
                }
                group.addTask {
                    try await self.follow(self.repositories.ingredients.watchAll(), .catalog) {
                        self.catalog = $0
                        self.ingredientsById = Dictionary($0.map { ($0.id, $0) }) { _, last in
                            last
                        }
                    }
                }
                group.addTask {
                    try await self.follow(self.repositories.swipeEvents.watchAll(), .events) {
                        self.log.merge($0, now: self.now())
                    }
                }
                group.addTask {
                    try await self.follow(self.repositories.mealLogs.watchAll(), .history) {
                        self.mealLogs = $0
                    }
                }
                group.addTask { try await self.followDays() }
                // Every child loops until cancelled, so the first to finish at all is a
                // failure; report it immediately instead of waiting for the rest to unwind.
                try await group.next()
                group.cancelAll()
            }
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(
                String(localized: "Your dishes couldn't be loaded. (\(String(describing: error)))"))
        }
    }

    /// Re-derives Today's picks for the current date, and rebuilds the deck (top card kept)
    /// if the clock moved into another meal slot. Called at midnight and when the app
    /// returns to the foreground.
    func refreshForNewDay() async {
        refreshPicks()
        let slot = mealTypeOverride ?? MealHistory.currentMealType(now: now(), calendar: calendar())
        if slot != mealType { await rebuild(pinningTop: true) }
    }

    // MARK: Deck actions

    /// Switches mode and starts a new deck. Ignored while a swipe is being written.
    func setMode(_ newMode: SwipeMode) async {
        guard newMode != mode, !isWriting else { return }
        mode = newMode
        await startNewDeck()
    }

    /// Overrides the meal slot (`nil` follows the clock again) and starts a new deck.
    func setMealType(_ meal: MealType?) async {
        guard meal != mealTypeOverride, !isWriting else { return }
        mealTypeOverride = meal
        await startNewDeck()
    }

    /// Starts a new deck with a new seed.
    func shuffle() async {
        guard !isWriting else { return }
        let next = makeSeed()
        deckSeed = next == deckSeed ? next &+ 1 : next
        await startNewDeck()
    }

    // MARK: Private

    private func follow<Element: Sendable>(
        _ stream: AsyncThrowingStream<[Element], any Error>, _ source: Source,
        apply: @MainActor ([Element]) -> Void
    ) async throws {
        for try await snapshot in stream {
            apply(snapshot)
            await sourceChanged(source)
        }
    }

    private func sourceChanged(_ source: Source) async {
        let wasLoaded = loaded.count == Source.allCases.count
        loaded.insert(source)
        refreshPicks()
        guard loaded.count == Source.allCases.count else { return }
        if !wasLoaded {
            phase = .loaded
            await rebuild(pinningTop: !cards.isEmpty)
        } else if source != .events {
            await rebuild(pinningTop: true)
        }
    }

    private func startNewDeck() async {
        sessionSwipedIds = []
        lastSwipe = nil
        cards = []
        await rebuild(pinningTop: false)
    }

    private func rebuild(pinningTop: Bool) async {
        guard loaded.count == Source.allCases.count else { return }
        buildGeneration += 1
        let generation = buildGeneration
        mealType = mealTypeOverride ?? MealHistory.currentMealType(now: now(), calendar: calendar())
        let request = DeckRequest(
            recipes: recipes, pantry: pantry, catalog: catalog, events: log.events,
            mealLogs: mealLogs, now: now(), calendar: calendar(), mealType: mealType, mode: mode,
            seed: deckSeed)
        isBuilding = true
        let built = await Self.build(request)
        guard generation == buildGeneration else { return }
        isBuilding = false
        let excluded = sessionSwipedIds.union(pickedRecipeIds)
        guard pinningTop else {
            cards = DeckRefresh.fresh(built, excluding: excluded)
            return
        }
        // The top card stays unless its recipe was deleted. A hidden flag is not checked: the
        // snapshot may predate an undo of "Never show" that just put this card back.
        let storedIds = Set(recipes.map(\.id))
        cards = DeckRefresh.refreshed(
            current: cards, rebuilt: built, excluding: excluded,
            keepingTopIf: { storedIds.contains($0.recipe.id) })
    }

    /// Runs the (pure) deck build on the concurrent pool, off the main actor.
    @concurrent
    private static func build(_ request: DeckRequest) async -> [ScoredRecipe] {
        request.build()
    }

    func refreshPicks() {
        let derived = TodaysPicks.derive(
            events: log.events, mealLogs: mealLogs, now: now(), calendar: calendar())
        pickedRecipeIds = Set(derived.map(\.recipeId))
        let rows = PickRow.rows(
            for: derived, recipes: recipes, ingredientsById: ingredientsById, pantry: pantryById)
        if rows != picks { picks = rows }
    }
}
