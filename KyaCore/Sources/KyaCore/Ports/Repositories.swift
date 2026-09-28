// Repository ports `KyaCore` depends on but never implements (ADR 004/009,
// `AGENTS.md` section 5.3). The app's `KyaBnaye/Data/` layer provides
// SwiftData-backed adapters; `@Observable` stores and use cases depend only on
// these protocols, so swapping storage later (v2 cloud sync) is a new adapter
// with zero changes here. No SwiftData `@Model` type ever crosses a port.
//
// Shared contract for every repository (executable form: the
// `KyaCoreContracts` library, which every adapter's tests must pass):
// - Reads return fresh immutable value snapshots, in the documented order.
//   Orders never depend on hash or storage order; ties are broken by id.
// - Each batch write is atomic: afterwards, reads and observers see all of it
//   or, if it throws, none of it.
// - `watchAll()` returns a new independent stream per call. Its first element
//   is the full state at (or after) subscription; after every committed write
//   it emits the full new state. Intermediate states may be coalesced, so treat
//   each element as "the latest state", never as a diff. The stream ends when
//   the consumer stops iterating (task cancellation) and throws if the
//   underlying store fails. A cancelled observer never blocks writes.
// - Errors: storage failures propagate as thrown errors (never swallowed);
//   contract violations by the caller throw ``RepositoryError``.

import Foundation

/// A repository contract violation reported by an adapter.
public enum RepositoryError: Error, Sendable, Equatable {
    /// An append-only `add` was given an id that is already stored. History is
    /// never overwritten.
    case duplicateId(String)

    /// A targeted update (e.g. ticking an item off) named an id that is not
    /// stored. Nothing was written.
    case notFound(String)
}

/// The ingredient catalog: seed rows plus user-created ingredients
/// (``Ingredient/isUserCreated``).
public protocol IngredientRepository: Sendable {
    /// Every ingredient, sorted by ``Ingredient/id`` ascending.
    ///
    /// - Returns: A snapshot of the catalog.
    /// - Throws: A storage error if the read fails.
    func all() async throws -> [Ingredient]

    /// Observes the catalog, in the order of ``all()`` (see the shared stream
    /// contract at the top of this file).
    ///
    /// - Returns: A new stream of full catalog snapshots.
    func watchAll() -> AsyncThrowingStream<[Ingredient], any Error>

    /// Inserts or fully replaces ingredients keyed on ``Ingredient/id``,
    /// atomically — e.g. a user-created ingredient or a user edit. If an id
    /// repeats within `ingredients`, the last occurrence wins.
    ///
    /// - Parameter ingredients: The rows to write; empty is a no-op.
    /// - Throws: A storage error; nothing is written in that case.
    func upsert(_ ingredients: [Ingredient]) async throws

    /// Inserts only the ingredients whose id is not stored yet, atomically.
    /// Existing rows are never modified, which protects user edits when a new
    /// seed version is applied (see ``SeedSync``). If an id repeats within
    /// `ingredients`, the first occurrence wins.
    ///
    /// - Parameter ingredients: Candidate rows; empty is a no-op.
    /// - Returns: The ids actually inserted, sorted ascending.
    /// - Throws: A storage error; nothing is written in that case.
    func insertMissing(_ ingredients: [Ingredient]) async throws -> [String]
}

/// The recipe book: seed recipes plus the user's own.
public protocol RecipeRepository: Sendable {
    /// Every recipe (including hidden ones), sorted by ``Recipe/id`` ascending.
    ///
    /// - Returns: A snapshot of the recipe book.
    /// - Throws: A storage error if the read fails.
    func all() async throws -> [Recipe]

    /// Observes the recipe book, in the order of ``all()``.
    ///
    /// - Returns: A new stream of full recipe-book snapshots.
    func watchAll() -> AsyncThrowingStream<[Recipe], any Error>

    /// Looks up one recipe by id.
    ///
    /// - Parameter id: The ``Recipe/id`` to find.
    /// - Returns: The stored recipe, or `nil` if there is none.
    /// - Throws: A storage error if the read fails.
    func recipe(withId id: String) async throws -> Recipe?

    /// Inserts or fully replaces recipes keyed on ``Recipe/id``, atomically.
    /// Every field is replaced (note ``Recipe`` `==` compares ids only). If an
    /// id repeats within `recipes`, the last occurrence wins.
    ///
    /// - Parameter recipes: The recipes to write; empty is a no-op.
    /// - Throws: A storage error; nothing is written in that case.
    func upsert(_ recipes: [Recipe]) async throws

    /// Inserts only the recipes whose id is not stored yet, atomically.
    /// Existing recipes (including their favourite/hidden flags and any user
    /// edits) are never modified. If an id repeats within `recipes`, the first
    /// occurrence wins.
    ///
    /// - Parameter recipes: Candidate recipes; empty is a no-op.
    /// - Returns: The ids actually inserted, sorted ascending.
    /// - Throws: A storage error; nothing is written in that case.
    func insertMissing(_ recipes: [Recipe]) async throws -> [String]

    /// Sets ``Recipe/isFavorite`` on one stored recipe, leaving every other
    /// field unchanged.
    ///
    /// - Parameters:
    ///   - isFavorite: The new flag.
    ///   - id: The ``Recipe/id`` to update.
    /// - Throws: ``RepositoryError/notFound(_:)`` if `id` is not stored, or a
    ///   storage error; nothing is written in either case.
    func setFavorite(_ isFavorite: Bool, forRecipeWithId id: String) async throws

    /// Sets ``Recipe/isHidden`` ("Never show") on one stored recipe, leaving
    /// every other field unchanged.
    ///
    /// - Parameters:
    ///   - isHidden: The new flag.
    ///   - id: The ``Recipe/id`` to update.
    /// - Throws: ``RepositoryError/notFound(_:)`` if `id` is not stored, or a
    ///   storage error; nothing is written in either case.
    func setHidden(_ isHidden: Bool, forRecipeWithId id: String) async throws

    /// Deletes a recipe. Deleting an unknown id is a no-op. Meal logs and
    /// swipe events that reference it are kept (history is never rewritten).
    /// A deleted **seed** recipe comes back when a newer seed version is
    /// applied, so the UI should offer "hide" for seed recipes instead.
    ///
    /// - Parameter id: The ``Recipe/id`` to delete.
    /// - Throws: A storage error; nothing is deleted in that case.
    func delete(id: String) async throws
}
