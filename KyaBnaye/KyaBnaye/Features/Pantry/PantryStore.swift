import Foundation
import KyaCore
import Observation

/// State and actions for the Pantry tab: what is at home, grouped by category, with
/// tap-to-cycle levels, expiry estimates, alias-aware adding and "add to shopping list".
///
/// Reads and writes only through `KyaCore` repository ports. Every write updates the local
/// state as soon as it has been committed, and ``observe()`` keeps it in sync with changes
/// made elsewhere (e.g. "Move bought items to pantry").
@Observable
@MainActor
final class PantryStore {
    /// Where the pantry data is in loading.
    enum Phase: Equatable {
        /// Waiting for the first catalog and pantry snapshots.
        case loading
        /// Data is on screen.
        case loaded
        /// The data could not be read; the screen offers a retry.
        case failed(String)
    }

    /// How the expiry is set when saving the edit sheet.
    enum ExpiryChoice: Equatable {
        /// Follow the level rules: estimate when it becomes Plenty, keep it when Low, clear
        /// it when Out.
        case automatic
        /// A date the user picked.
        case date(Date)
        /// The user cleared the expiry.
        case none
    }

    /// The loading phase.
    private(set) var phase: Phase = .loading
    /// The selected filter chip.
    var filter: PantryFilter = .all
    /// The search / add field.
    var query = ""
    /// A failed action, shown as an alert until dismissed.
    var actionError: String?
    /// A short confirmation of the last action, shown briefly and announced to VoiceOver.
    var confirmation: String?

    private(set) var ingredientsById: [String: Ingredient] = [:]
    private(set) var itemsById: [String: PantryItem] = [:]
    @ObservationIgnored private var normalizer: IngredientNormalizer?
    @ObservationIgnored private var hasCatalog = false
    @ObservationIgnored private var hasStock = false
    @ObservationIgnored private let writes = SerialWriteQueue()

    @ObservationIgnored private let ingredients: any IngredientRepository
    @ObservationIgnored private let pantry: any PantryRepository
    @ObservationIgnored private let shopping: any ShoppingRepository
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let calendar: () -> Calendar
    @ObservationIgnored private let makeId: () -> String

    /// Creates the store.
    ///
    /// - Parameters:
    ///   - repositories: The ports to read and write through.
    ///   - now: The clock.
    ///   - calendar: The calendar defining "day" for expiry.
    ///   - makeId: New shopping item ids.
    init(
        repositories: RepositorySet,
        now: @escaping () -> Date,
        calendar: @escaping () -> Calendar,
        makeId: @escaping () -> String = { UUID().uuidString }
    ) {
        ingredients = repositories.ingredients
        pantry = repositories.pantry
        shopping = repositories.shopping
        self.now = now
        self.calendar = calendar
        self.makeId = makeId
    }

    // MARK: Derived state

    /// Pantry records grouped into category sections (fixed order), filtered by ``filter``.
    var sections: [PantrySection] {
        let rows = itemsById.values.compactMap(row(for:)).filter(matchesFilter)
        let grouped = Dictionary(grouping: rows) { $0.ingredient.category }
        return PantryRules.categoryOrder.compactMap { category in
            guard let rows = grouped[category], !rows.isEmpty else { return nil }
            return PantrySection(category: category, rows: rows.sorted(by: Self.byName))
        }
    }

    /// Staples with no record: assumed at home. Only listed under the "All" filter.
    var assumedStaples: [PantryRow] {
        guard filter == .all else { return [] }
        return ingredientsById.values
            .filter { $0.role == .staple && itemsById[$0.id] == nil }
            .map { PantryRow(ingredient: $0, item: nil, daysUntilExpiry: nil) }
            .sorted(by: Self.byName)
    }

    /// Whether nothing has been marked yet (staples aside).
    var isPantryEmpty: Bool {
        !itemsById.keys.contains { ingredientsById[$0] != nil }
    }

    /// Catalog suggestions for ``query``, best first (alias-aware: "aloo" → Potato).
    var suggestions: [PantryRow] {
        guard let normalizer else { return [] }
        return normalizer.suggestions(for: query).map { ingredient in
            row(for: ingredient)
        }
    }

    /// The trimmed query when it matches nothing exactly, so it can become a new ingredient.
    var newIngredientName: String? {
        let name = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let normalizer, normalizer.find(name) == nil else { return nil }
        return name
    }

    // MARK: Loading

    /// Reads the catalog and pantry once.
    func load() async {
        do {
            try apply(catalog: try await ingredients.all())
            apply(stock: try await pantry.all())
        } catch {
            phase = .failed(Self.loadFailureMessage(error))
        }
    }

    /// Follows the catalog and pantry until cancelled (the screen disappears).
    func observe() async {
        if case .failed = phase { phase = .loading }
        do {
            async let catalog: Void = observeCatalog()
            async let stock: Void = observeStock()
            _ = try await (catalog, stock)
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(Self.loadFailureMessage(error))
        }
    }

    // MARK: Actions

    // Every write goes through `writes`, so a quick double tap runs the second action
    // against the state the first one left, never against the same stale snapshot.

    /// Moves a row to its next level (Plenty → Low → Out → Plenty), counting from the level
    /// stored now rather than the one the row showed when it was tapped.
    func cycle(_ row: PantryRow) async {
        await writes.run {
            let level = PantryRules.nextLevel(after: self.itemsById[row.id]?.level)
            let item = self.item(for: row.ingredient, level: level, expiry: .automatic)
            _ = await self.write(item, name: row)
        }
    }

    /// Marks a catalog ingredient as Plenty (freshly bought) and clears the search.
    ///
    /// - Returns: Whether it was saved.
    @discardableResult
    func add(_ ingredient: Ingredient) async -> Bool {
        await writes.run { await self.markPlenty(ingredient) }
    }

    /// Adds typed text that matched nothing as a user ingredient, then marks it Plenty.
    ///
    /// If the text (possibly edited in the sheet) turns out to be the name or alias of an
    /// ingredient already in the catalog, that ingredient is used instead: saving a second
    /// ingredient with the same name would make every later catalog read fail.
    ///
    /// - Returns: Whether it was saved.
    @discardableResult
    func createAndAdd(name: String, category: IngredientCategory, buyFrom: BuyFrom) async -> Bool {
        await writes.run {
            await self.createAndMarkPlenty(name: name, category: category, buyFrom: buyFrom)
        }
    }

    /// Saves the edit sheet.
    ///
    /// - Returns: Whether it was saved.
    @discardableResult
    func save(_ row: PantryRow, level: StockLevel, expiry: ExpiryChoice) async -> Bool {
        await writes.run {
            await self.write(
                self.item(for: row.ingredient, level: level, expiry: expiry), name: row)
        }
    }

    /// Removes an ingredient from the pantry entirely (not the same as Out: it will not be
    /// auto-listed for shopping, and a staple goes back to "assumed at home").
    ///
    /// - Returns: Whether it was removed.
    @discardableResult
    func remove(_ row: PantryRow) async -> Bool {
        await writes.run {
            do {
                try await self.pantry.delete(ingredientIds: [row.id])
                self.itemsById[row.id] = nil
                self.confirmation = String(
                    localized: "\(row.ingredient.name) removed from pantry")
                return true
            } catch {
                self.actionError = String(
                    localized: "Couldn't remove \(row.ingredient.name). Please try again.")
                return false
            }
        }
    }

    /// Puts an ingredient on the shopping list, with Low/Out as the reason, unless it is
    /// already there and not ticked off.
    func addToShoppingList(_ row: PantryRow) async {
        await writes.run { await self.addToShoppingListNow(row) }
    }

    // MARK: Private

    private func markPlenty(_ ingredient: Ingredient) async -> Bool {
        let item = PantryItem(ingredientId: ingredient.id, level: .plenty, updatedAt: now())
            .withEstimatedExpiry(shelfLifeDays: ingredient.shelfLifeDays, calendar: calendar())
        guard await write(item, name: row(for: ingredient)) else { return false }
        query = ""
        confirmation = String(localized: "\(ingredient.name) marked Plenty")
        return true
    }

    private func createAndMarkPlenty(
        name: String, category: IngredientCategory, buyFrom: BuyFrom
    ) async -> Bool {
        do {
            if let existing = normalizer?.find(name) { return await markPlenty(existing) }
            let ingredient = try IngredientNormalizer.createUserIngredient(
                name, category: category, buyFrom: buyFrom)
            if let existing = normalizer?.ingredient(withId: ingredient.id) {
                return await markPlenty(existing)
            }
            let catalog = Array(ingredientsById.values) + [ingredient]
            try await ingredients.upsert([ingredient])
            try apply(catalog: catalog)
            return await markPlenty(ingredient)
        } catch {
            actionError = String(localized: "Couldn't add \(name). Please try again.")
            return false
        }
    }

    private func addToShoppingListNow(_ row: PantryRow) async {
        let name = row.ingredient.name
        do {
            let list = try await shopping.all()
            if list.contains(where: { !$0.isChecked && $0.ingredientId == row.id }) {
                confirmation = String(localized: "\(name) is already on your shopping list")
                return
            }
            let reason: ShoppingReason =
                switch itemsById[row.id]?.level ?? row.effectiveLevel {
                case .out: .out
                case .low: .low
                case .plenty: .manual
                }
            let item = try ShoppingItem(
                id: makeId(), ingredientId: row.id, reason: reason, isChecked: false,
                createdAt: now())
            try await shopping.upsert([item])
            confirmation = String(localized: "\(name) added to your shopping list")
        } catch {
            actionError = String(
                localized: "Couldn't add \(name) to the shopping list. Please try again.")
        }
    }

    private func observeCatalog() async throws {
        for try await snapshot in ingredients.watchAll() {
            try apply(catalog: snapshot)
        }
    }

    private func observeStock() async throws {
        for try await snapshot in pantry.watchAll() {
            apply(stock: snapshot)
        }
    }

    private func apply(catalog: [Ingredient]) throws {
        let normalizer = try IngredientNormalizer(catalog)
        self.normalizer = normalizer
        ingredientsById = Dictionary(normalizer.all.map { ($0.id, $0) }) { _, last in last }
        hasCatalog = true
        markLoadedIfReady()
    }

    private func apply(stock: [PantryItem]) {
        itemsById = Dictionary(stock.map { ($0.ingredientId, $0) }) { _, last in last }
        hasStock = true
        markLoadedIfReady()
    }

    private func markLoadedIfReady() {
        if hasCatalog && hasStock { phase = .loaded }
    }

    /// Writes one record and mirrors it locally; reports a failure as an alert.
    @discardableResult
    private func write(_ item: PantryItem, name row: PantryRow) async -> Bool {
        do {
            try await pantry.setLevels([item])
            itemsById[item.ingredientId] = item
            return true
        } catch {
            actionError = String(
                localized: "Couldn't update \(row.ingredient.name). Please try again.")
            return false
        }
    }

    /// The record for `ingredient` at `level`, stamped now.
    private func item(
        for ingredient: Ingredient, level: StockLevel, expiry: ExpiryChoice
    ) -> PantryItem {
        let stamped = PantryItem(ingredientId: ingredient.id, level: level, updatedAt: now())
        switch expiry {
        case .date(let date):
            return stamped.withExpiresOn(date)
        case .none:
            return stamped
        case .automatic:
            break
        }
        let existing = itemsById[ingredient.id]
        switch level {
        case .plenty where existing?.level != .plenty:
            return stamped.withEstimatedExpiry(
                shelfLifeDays: ingredient.shelfLifeDays, calendar: calendar())
        case .plenty, .low:
            return stamped.withExpiresOn(existing?.expiresOn)
                .copy(expiryIsEstimated: existing?.expiryIsEstimated ?? false)
        case .out:
            return stamped
        }
    }

    private func row(for item: PantryItem) -> PantryRow? {
        ingredientsById[item.ingredientId].map { row(for: $0) }
    }

    private func row(for ingredient: Ingredient) -> PantryRow {
        let item = itemsById[ingredient.id]
        return PantryRow(
            ingredient: ingredient, item: item,
            daysUntilExpiry: item?.daysUntilExpiry(asOf: now(), calendar: calendar()))
    }

    private func matchesFilter(_ row: PantryRow) -> Bool {
        switch filter {
        case .all:
            true
        case .low:
            row.effectiveLevel != .plenty
        case .expiring:
            row.effectiveLevel != .out
                && (row.daysUntilExpiry.map { $0 <= PantryRules.expiringWindowDays } ?? false)
        }
    }

    private static func byName(_ lhs: PantryRow, _ rhs: PantryRow) -> Bool {
        let order = lhs.ingredient.name.localizedStandardCompare(rhs.ingredient.name)
        return order == .orderedSame ? lhs.id < rhs.id : order == .orderedAscending
    }

    private static func loadFailureMessage(_ error: any Error) -> String {
        String(localized: "Your pantry couldn't be loaded. (\(String(describing: error)))")
    }
}
