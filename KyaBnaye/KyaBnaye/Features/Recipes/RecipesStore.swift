import Foundation
import KyaCore
import Observation

/// One row of the recipe list: the recipe and whether it can be cooked right now.
struct RecipeRow: Identifiable, Equatable {
    /// The recipe.
    let recipe: Recipe
    /// Its pantry status (staples assumed).
    let cookability: RecipeCookability

    /// The recipe id.
    var id: String { recipe.id }

    /// "Ready" or "N missing": the status shown on the row and read by VoiceOver.
    var statusText: String {
        cookability.isReady
            ? String(localized: "Ready")
            : String(localized: "\(cookability.missingCount) missing")
    }

    static func == (lhs: RecipeRow, rhs: RecipeRow) -> Bool {
        lhs.recipe.isIdentical(to: rhs.recipe) && lhs.cookability == rhs.cookability
    }
}

/// State and actions for the Recipes tab and recipe detail: the recipe book filtered by
/// search and chips, each recipe's cookable status, favourite/hide/delete and "Add missing
/// to shopping list".
///
/// Reads and writes only through `KyaCore` repository ports and follows every source it
/// depends on (recipes, catalog, pantry, meal history) while ``observe()`` runs, so a pantry
/// change elsewhere updates the "ready / N missing" marks at once.
@Observable
@MainActor
final class RecipesStore {
    /// Where the recipe data is in loading.
    enum Phase: Equatable {
        /// Waiting for the first snapshots.
        case loading
        /// Data is on screen.
        case loaded
        /// The data could not be read; the screen offers a retry.
        case failed(String)
    }

    /// The loading phase.
    private(set) var phase: Phase = .loading
    /// Search text and filter chips.
    var filter = RecipeFilter()
    /// A failed action, shown as an alert until dismissed.
    var actionError: String?
    /// A short confirmation of the last action, shown briefly and announced to VoiceOver.
    var confirmation: String?

    private(set) var recipes: [Recipe] = []
    private(set) var ingredientsById: [String: Ingredient] = [:]
    private(set) var pantryById: [String: PantryItem] = [:]
    private(set) var lastCookedByRecipe: [String: Date] = [:]
    @ObservationIgnored private var loaded: Set<Source> = []

    @ObservationIgnored private let repositories: RepositorySet
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let calendar: () -> Calendar
    @ObservationIgnored private let makeId: () -> String

    private enum Source { case recipes, catalog, pantry, history }

    /// Creates the store.
    ///
    /// - Parameters:
    ///   - repositories: The ports to read and write through.
    ///   - now: The clock.
    ///   - calendar: The calendar defining "day" for "last made".
    ///   - makeId: New shopping item and swipe event ids.
    init(
        repositories: RepositorySet,
        now: @escaping () -> Date,
        calendar: @escaping () -> Calendar,
        makeId: @escaping () -> String = { UUID().uuidString }
    ) {
        self.repositories = repositories
        self.now = now
        self.calendar = calendar
        self.makeId = makeId
    }

    // MARK: Derived state

    /// The visible recipes matching ``filter``, sorted by name.
    var rows: [RecipeRow] {
        RecipeBook.browse(recipes, filter: filter, cookability: cookability(for:))
            .map { RecipeRow(recipe: $0, cookability: cookability(for: $0)) }
    }

    /// Hidden ("Never show") recipes, so they can be found and unhidden.
    var hiddenRecipes: [Recipe] { RecipeBook.hidden(recipes) }

    /// Whether the book has no visible recipe at all (as opposed to none matching filters).
    var hasNoVisibleRecipes: Bool { !recipes.contains { !$0.isHidden } }

    /// The stored recipe with `id`, if any.
    func recipe(withId id: String) -> Recipe? {
        recipes.first { $0.id == id }
    }

    /// `recipe`'s have/missing status against the current pantry.
    func cookability(for recipe: Recipe) -> RecipeCookability {
        RecipeCookability.evaluate(recipe, ingredientsById: ingredientsById, pantry: pantryById)
    }

    /// Calendar days since `recipeId` was last cooked, or `nil` if never.
    func daysSinceLastCooked(_ recipeId: String) -> Int? {
        lastCookedByRecipe[recipeId].map {
            MealHistory.daysSince($0, now: now(), calendar: calendar())
        }
    }

    // MARK: Loading

    /// Follows recipes, catalog, pantry and history until cancelled.
    ///
    /// Each screen showing this store's data (the list, a pushed detail) runs this while it
    /// is on screen, because a `.task` stops when its view is covered by a pushed screen.
    /// Restarting keeps the data already shown instead of flashing back to loading; only a
    /// failed load starts over.
    func observe() async {
        if case .failed = phase { phase = .loading }
        loaded = []
        do {
            async let recipes: Void = observeRecipes()
            async let catalog: Void = observeCatalog()
            async let pantry: Void = observePantry()
            async let history: Void = observeHistory()
            _ = try await (recipes, catalog, pantry, history)
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(
                String(localized: "Your recipes couldn't be loaded. (\(String(describing: error)))")
            )
        }
    }

    // MARK: Actions

    /// Flips a recipe's favourite flag.
    func toggleFavorite(_ recipe: Recipe) async {
        let target = !(self.recipe(withId: recipe.id)?.isFavorite ?? recipe.isFavorite)
        await perform(String(localized: "Couldn't update \(recipe.name). Please try again.")) {
            try await self.repositories.recipes.setFavorite(target, forRecipeWithId: recipe.id)
            self.replace(recipe.id) { $0.copy(isFavorite: target) }
            self.confirmation =
                target
                ? String(localized: "\(recipe.name) added to favourites")
                : String(localized: "\(recipe.name) removed from favourites")
        }
    }

    /// Hides a recipe from the book and every deck, or shows it again.
    ///
    /// Unhiding also revokes any "Never show" swipe still in force for it (``RecipeUnhide``),
    /// so the dish returns to the deck as well as the book. The undo events are appended
    /// first: if clearing the flag then fails, the dish simply stays hidden.
    func setHidden(_ isHidden: Bool, for recipe: Recipe) async {
        await perform(String(localized: "Couldn't update \(recipe.name). Please try again.")) {
            if !isHidden {
                let undos = RecipeUnhide.undoEvents(
                    for: recipe.id, in: try await self.repositories.swipeEvents.all(),
                    now: self.now(), nextId: self.makeId)
                for event in undos { try await self.repositories.swipeEvents.add(event) }
            }
            try await self.repositories.recipes.setHidden(isHidden, forRecipeWithId: recipe.id)
            self.replace(recipe.id) { $0.copy(isHidden: isHidden) }
            self.confirmation =
                isHidden
                ? String(localized: "\(recipe.name) hidden")
                : String(localized: "\(recipe.name) is back in your recipes")
        }
    }

    /// Deletes one of the user's own recipes. Seed recipes are hidden instead, because a
    /// deleted seed recipe returns with the next seed update.
    ///
    /// - Returns: Whether it was deleted.
    @discardableResult
    func delete(_ recipe: Recipe) async -> Bool {
        guard recipe.source == .user else {
            await setHidden(true, for: recipe)
            return false
        }
        var deleted = false
        await perform(String(localized: "Couldn't delete \(recipe.name). Please try again.")) {
            try await self.repositories.recipes.delete(id: recipe.id)
            self.recipes.removeAll { $0.id == recipe.id }
            self.confirmation = String(localized: "\(recipe.name) deleted")
            deleted = true
        }
        return deleted
    }

    /// Puts the recipe's missing ingredients on the shopping list (reason "recipe"),
    /// skipping any already listed and not ticked off.
    ///
    /// - Returns: How many items were added.
    @discardableResult
    func addMissingToShoppingList(_ recipe: Recipe) async -> Int {
        var added = 0
        await perform(String(localized: "Couldn't update the shopping list. Please try again.")) {
            let items = RecipeShoppingPlan.missingItems(
                for: recipe, ingredientsById: self.ingredientsById, pantry: self.pantryById,
                existingItems: try await self.repositories.shopping.all(), now: self.now(),
                nextId: self.makeId)
            try await self.repositories.shopping.upsert(items)
            added = items.count
            self.confirmation =
                items.isEmpty
                ? String(localized: "Everything missing is already on your list")
                : String(localized: "Added \(items.count) to your shopping list")
        }
        return added
    }

    // MARK: Private

    private func observeRecipes() async throws {
        for try await snapshot in repositories.recipes.watchAll() {
            recipes = snapshot
            markLoaded(.recipes)
        }
    }

    private func observeCatalog() async throws {
        for try await snapshot in repositories.ingredients.watchAll() {
            ingredientsById = Dictionary(snapshot.map { ($0.id, $0) }) { _, last in last }
            markLoaded(.catalog)
        }
    }

    private func observePantry() async throws {
        for try await snapshot in repositories.pantry.watchAll() {
            pantryById = Dictionary(snapshot.map { ($0.ingredientId, $0) }) { _, last in last }
            markLoaded(.pantry)
        }
    }

    private func observeHistory() async throws {
        for try await snapshot in repositories.mealLogs.watchAll() {
            lastCookedByRecipe = MealHistory.lastCooked(snapshot)
            markLoaded(.history)
        }
    }

    private func markLoaded(_ source: Source) {
        loaded.insert(source)
        if loaded.count == 4, phase != .loaded { phase = .loaded }
    }

    private func perform(_ failure: String, _ action: () async throws -> Void) async {
        do {
            try await action()
        } catch {
            actionError = failure
        }
    }

    private func replace(_ id: String, _ change: (Recipe) -> Recipe) {
        guard let index = recipes.firstIndex(where: { $0.id == id }) else { return }
        recipes[index] = change(recipes[index])
    }
}
