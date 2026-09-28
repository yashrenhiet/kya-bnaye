import Foundation

/// Household stock levels, one ``PantryItem`` per ingredient. Follows the
/// shared repository contract documented in `Repositories.swift`.
public protocol PantryRepository: Sendable {
    /// Every pantry record, sorted by ``PantryItem/ingredientId`` ascending.
    ///
    /// - Returns: A snapshot of the pantry.
    /// - Throws: A storage error if the read fails.
    func all() async throws -> [PantryItem]

    /// Observes the pantry, in the order of ``all()``.
    ///
    /// - Returns: A new stream of full pantry snapshots.
    func watchAll() -> AsyncThrowingStream<[PantryItem], any Error>

    /// Inserts or fully replaces pantry records keyed on
    /// ``PantryItem/ingredientId`` (the primary key, `AGENTS.md` section 5.4),
    /// atomically — e.g. the confirmed "Used up anything?" changes after
    /// "I made this", or a single tap-to-cycle. Postcondition: at most one
    /// record per ingredient id. If an id repeats within `items`, the last
    /// occurrence wins.
    ///
    /// - Parameter items: The records to write; empty is a no-op.
    /// - Throws: A storage error; nothing is written in that case.
    func setLevels(_ items: [PantryItem]) async throws

    /// Removes pantry records by ingredient id, atomically — "Remove from
    /// pantry" when the household no longer keeps an ingredient. Unlike
    /// marking it ``StockLevel/out``, a removed ingredient is not auto-listed
    /// for shopping; for a staple, no record means "assumed present" again.
    /// Unknown ids are ignored.
    ///
    /// - Parameter ingredientIds: The ``PantryItem/ingredientId``s to remove.
    /// - Throws: A storage error; nothing is removed in that case.
    func delete(ingredientIds: Set<String>) async throws
}

/// The shopping list. Follows the shared repository contract documented in
/// `Repositories.swift`.
public protocol ShoppingRepository: Sendable {
    /// Every item in list order: the order in which ids were first inserted.
    /// Re-upserting an existing id (e.g. ticking it off) keeps its position, so
    /// a batch from ``ShoppingListBuilder/build(pantry:ingredientsById:existingItems:recipesToShopFor:now:nextId:)``
    /// keeps the builder's order.
    ///
    /// - Returns: A snapshot of the list.
    /// - Throws: A storage error if the read fails.
    func all() async throws -> [ShoppingItem]

    /// Observes the list, in the order of ``all()``.
    ///
    /// - Returns: A new stream of full list snapshots.
    func watchAll() -> AsyncThrowingStream<[ShoppingItem], any Error>

    /// Inserts new items (appended in the given order) or fully replaces
    /// existing ones keyed on ``ShoppingItem/id``, atomically. If an id repeats
    /// within `items`, the last occurrence wins, at the first occurrence's
    /// position.
    ///
    /// - Parameter items: The items to write; empty is a no-op.
    /// - Throws: A storage error; nothing is written in that case.
    func upsert(_ items: [ShoppingItem]) async throws

    /// Ticks one item off (or back on), leaving every other field and its list
    /// position unchanged.
    ///
    /// - Parameters:
    ///   - isChecked: The new ``ShoppingItem/isChecked`` value.
    ///   - id: The ``ShoppingItem/id`` to update.
    /// - Throws: ``RepositoryError/notFound(_:)`` if `id` is not stored, or a
    ///   storage error; nothing is written in either case.
    func setChecked(_ isChecked: Bool, forItemWithId id: String) async throws

    /// Deletes items by id, atomically (e.g. after "Move bought items to
    /// pantry"). Unknown ids are ignored; the rest keep their relative order.
    ///
    /// - Parameter ids: The ``ShoppingItem/id``s to delete.
    /// - Throws: A storage error; nothing is deleted in that case.
    func delete(ids: Set<String>) async throws
}

/// Which bundled seed version has been applied (`seed/manifest.json`'s
/// `seedVersion`), so later seed releases add rows without clobbering user
/// edits (see ``SeedSync``).
public protocol SeedStateRepository: Sendable {
    /// The last fully applied seed version.
    ///
    /// - Returns: The stored version, or `nil` on first run.
    /// - Throws: A storage error if the read fails.
    func seedVersion() async throws -> Int?

    /// Records that `version` has been fully applied. Call only after every
    /// seed row has been written, so a crash mid-seed re-runs the (idempotent)
    /// seeding on next launch.
    ///
    /// - Parameter version: The applied seed version.
    /// - Throws: A storage error; the previous value is kept in that case.
    func setSeedVersion(_ version: Int) async throws
}
