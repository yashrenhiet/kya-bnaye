import Foundation
import KyaCore
import Observation

/// The outcome of "+ Add item".
enum ShoppingAddResult: Equatable, Sendable {
    /// A row was added; `name` is what the list now shows.
    case added(name: String)
    /// The text was blank; nothing was added.
    case blank
    /// The same thing is already on the list; nothing was added.
    case alreadyListed(name: String)
    /// Saving failed; `message` says so in plain words. Nothing was added.
    case failed(message: String)
}

/// State and actions for the Shopping tab (F6): the list, auto-filled from Low/Out pantry
/// items (see ``ShoppingAutoFill`` for when and how), grouped by vendor, with manual
/// entries, ticking, deleting and "Move bought items to pantry".
///
/// Every change goes through the KyaCore repositories; the observed streams then refresh
/// the screen, and each action also re-reads the list so the result shows at once.
@Observable
@MainActor
final class ShoppingStore {
    /// Where the screen is in loading its data.
    enum Phase: Equatable {
        /// The first read is in flight.
        case loading
        /// Data is on screen.
        case loaded
        /// The data could not be read; `message` says what to do.
        case failed(message: String)
    }

    /// Where the screen is in loading its data.
    private(set) var phase: Phase = .loading
    /// The list, in stored order.
    private(set) var items: [ShoppingItem] = []
    /// The last failed action, shown as an alert until dismissed.
    var actionError: String?

    @ObservationIgnored private let repositories: RepositorySet
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private let calendar: @MainActor () -> Calendar
    @ObservationIgnored private let makeId: @Sendable () -> String
    @ObservationIgnored private var autoFill = ShoppingAutoFill()
    @ObservationIgnored private var pantry: [PantryItem] = []
    @ObservationIgnored private var isFilling = false
    @ObservationIgnored private var needsRefill = false
    private var catalog: [Ingredient] = []
    private var recipeNamesById: [String: String] = [:]

    /// Creates the store.
    ///
    /// - Parameters:
    ///   - repositories: The data.
    ///   - now: The clock.
    ///   - calendar: Defines "day" for restock expiry estimates.
    ///   - makeId: Supplies new shopping item ids; UUIDs by default.
    init(
        repositories: RepositorySet,
        now: @escaping @Sendable () -> Date,
        calendar: @escaping @MainActor () -> Calendar,
        makeId: @escaping @Sendable () -> String = { UUID().uuidString }
    ) {
        self.repositories = repositories
        self.now = now
        self.calendar = calendar
        self.makeId = makeId
    }

    // MARK: Derived state

    /// Turns items into display rows.
    var presenter: ShoppingPresenter {
        ShoppingPresenter(
            ingredientsById: Dictionary(catalog.map { ($0.id, $0) }) { _, last in last },
            recipeNamesById: recipeNamesById)
    }

    /// Non-empty vendor sections, in Sabziwala / Kirana / Dairy / Other order.
    var sections: [ShoppingSection] { presenter.sections(for: items) }

    /// How many rows are ticked, i.e. what "Move N bought items to pantry" moves.
    var checkedCount: Int { items.count(where: \.isChecked) }

    /// The plain-text list to share; empty when nothing is left to buy.
    var shareText: String { presenter.shareText(for: items) }

    /// Autocomplete for the "Add item" field.
    func suggestions(for text: String) -> [IngredientSuggestion] {
        IngredientSuggester.suggestions(for: text, in: catalog)
    }

    // MARK: Loading

    /// Reads everything once and auto-fills. Shows ``Phase/failed(message:)`` if a read
    /// fails; call again to retry.
    func load() async {
        if case .failed = phase { phase = .loading }
        do {
            catalog = try await repositories.ingredients.all()
            recipeNamesById = Self.names(try await repositories.recipes.all())
            pantry = try await repositories.pantry.all()
            items = try await repositories.shopping.all()
            phase = .loaded
        } catch {
            phase = .failed(message: Self.loadFailureMessage)
            return
        }
        await fillFromPantry()
    }

    /// Keeps the screen live until cancelled: list, catalog and recipe changes refresh it,
    /// and pantry changes also auto-fill. Call after ``load()`` from the view's task.
    func observe() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.observeShopping() }
            group.addTask { await self.observeCatalog() }
            group.addTask { await self.observeRecipes() }
            group.addTask { await self.observePantry() }
        }
    }

    // MARK: Actions

    /// Ticks an item off, or back on.
    func setChecked(_ isChecked: Bool, itemId: String) async {
        await perform(String(localized: "Couldn't update that item.")) {
            try await self.repositories.shopping.setChecked(isChecked, forItemWithId: itemId)
        }
    }

    /// Deletes rows. Auto-added rows stay gone while the pantry is unchanged.
    func delete(itemIds: Set<String>) async {
        let byId = Dictionary(pantry.map { ($0.ingredientId, $0) }) { _, last in last }
        let deleted = items.filter { itemIds.contains($0.id) }
        await perform(String(localized: "Couldn't delete that item.")) {
            try await self.repositories.shopping.delete(ids: itemIds)
            for item in deleted { self.autoFill.recordDeletion(of: item, pantry: byId) }
        }
    }

    /// Adds what the user typed. Text that exactly matches a catalog name or alias becomes
    /// that ingredient (so it restocks the pantry when bought); anything else is kept as
    /// typed. Nothing is added when the same thing is already on the list.
    ///
    /// - Parameter text: The typed text.
    /// - Returns: What happened, so the sheet can explain a no-op.
    @discardableResult
    func addItem(named text: String) async -> ShoppingAddResult {
        let key = IngredientNormalizer.normalise(text)
        guard !key.isEmpty else { return .blank }
        let ingredient = catalog.first { ingredient in
            ([ingredient.name] + ingredient.aliases).contains {
                IngredientNormalizer.normalise($0) == key
            }
        }
        if let existing = items.first(where: { item in
            !item.isChecked && Self.matches(item, ingredient: ingredient, key: key)
        }) {
            return .alreadyListed(name: presenter.name(of: existing))
        }
        let item: ShoppingItem
        do {
            item = try ShoppingItem(
                id: makeId(), ingredientId: ingredient?.id,
                customName: ingredient == nil
                    ? text.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                reason: .manual, isChecked: false, createdAt: now())
        } catch {
            return .blank
        }
        do {
            try await repositories.shopping.upsert([item])
            items = try await repositories.shopping.all()
        } catch {
            return .failed(message: String(localized: "Couldn't add that item. Please try again."))
        }
        return .added(name: presenter.name(of: item))
    }

    /// Adds a catalog ingredient picked from the suggestions.
    ///
    /// - Parameter suggestion: The picked suggestion.
    /// - Returns: What happened.
    @discardableResult
    func addSuggestion(_ suggestion: IngredientSuggestion) async -> ShoppingAddResult {
        await addItem(named: suggestion.name)
    }

    /// Restocks every ticked catalog item to Plenty (with a fresh expiry estimate) and
    /// clears the ticked rows.
    func moveBoughtItemsToPantry() async {
        let move = MoveBoughtItemsToPantry(
            shopping: repositories.shopping, pantry: repositories.pantry,
            ingredients: repositories.ingredients)
        let now = now()
        let calendar = calendar()
        await perform(
            String(localized: "Couldn't move the bought items. Nothing was lost; try again.")
        ) {
            try await move(now: now, calendar: calendar)
        }
    }

    // MARK: Internals

    private static let loadFailureMessage = String(
        localized: "We couldn't open your shopping list. Please try again.")

    private static func names(_ recipes: [Recipe]) -> [String: String] {
        Dictionary(recipes.map { ($0.id, $0.name) }) { _, last in last }
    }

    private static func matches(_ item: ShoppingItem, ingredient: Ingredient?, key: String) -> Bool
    {
        if let ingredient { return item.ingredientId == ingredient.id && item.customName == nil }
        return item.customName.map { IngredientNormalizer.normalise($0) == key } ?? false
    }

    /// Runs `write`, then re-reads the list; a failure becomes ``actionError``.
    private func perform(_ failure: String, _ write: () async throws -> Void) async {
        do {
            try await write()
            items = try await repositories.shopping.all()
        } catch {
            actionError = failure
        }
    }

    /// Adds Low/Out rows for the current pantry. Runs one pass at a time; a request that
    /// arrives mid-pass triggers one more pass with the newest data, so two quick pantry
    /// changes can never both add the same row.
    private func fillFromPantry() async {
        guard !isFilling else {
            needsRefill = true
            return
        }
        isFilling = true
        defer { isFilling = false }
        repeat {
            needsRefill = false
            do {
                let existing = try await repositories.shopping.all()
                let byId = Dictionary(catalog.map { ($0.id, $0) }) { _, last in last }
                let new = autoFill.newItems(
                    pantry: pantry, ingredientsById: byId, existing: existing, now: now(),
                    nextId: makeId)
                if !new.isEmpty { try await repositories.shopping.upsert(new) }
                items = try await repositories.shopping.all()
            } catch {
                actionError = String(localized: "Couldn't add your Low and Out items to the list.")
                return
            }
        } while needsRefill
    }

    private func observeShopping() async {
        do {
            for try await snapshot in repositories.shopping.watchAll() { items = snapshot }
        } catch {
            phase = .failed(message: Self.loadFailureMessage)
        }
    }

    private func observeCatalog() async {
        do {
            for try await snapshot in repositories.ingredients.watchAll() { catalog = snapshot }
        } catch {
            phase = .failed(message: Self.loadFailureMessage)
        }
    }

    private func observeRecipes() async {
        do {
            for try await snapshot in repositories.recipes.watchAll() {
                recipeNamesById = Self.names(snapshot)
            }
        } catch {
            phase = .failed(message: Self.loadFailureMessage)
        }
    }

    private func observePantry() async {
        do {
            for try await snapshot in repositories.pantry.watchAll() where snapshot != pantry {
                pantry = snapshot
                await fillFromPantry()
            }
        } catch {
            phase = .failed(message: Self.loadFailureMessage)
        }
    }
}
