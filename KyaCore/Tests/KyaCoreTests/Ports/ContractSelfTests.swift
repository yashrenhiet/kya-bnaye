import Foundation
import KyaCore
import KyaCoreContracts
import Testing

/// Proves the contract suite catches broken adapters: each deliberately
/// faulty repository below must fail the named checks with a useful message.
@Suite("KyaCoreContracts detects broken adapters")
struct ContractSelfTests {
    private static let quick: Duration = .milliseconds(100)

    private func failingChecks<Subject: Sendable>(
        _ checks: [ContractCheck<Subject>], _ make: @escaping () -> Subject
    ) async -> [String: ContractFailure] {
        let failures = await ContractCheck.failures(of: checks) { make() }
        return Dictionary(failures.map { ($0.check, $0) }) { first, _ in first }
    }

    @Test("a pantry that drops writes fails the storage and stream checks")
    func forgetfulPantry() async throws {
        let failures = await failingChecks(
            RepositoryContracts.pantry(streamTimeout: Self.quick)
        ) { ForgetfulPantry() as any PantryRepository }

        let sorted = try #require(
            failures["PantryRepository: all() is sorted by ingredientId with every field kept"])
        #expect(sorted.message.hasPrefix("all(): expected ["))
        #expect(sorted.location.contains("HouseholdContracts.swift:"))
        #expect(sorted.description.hasPrefix("PantryRepository: all() is sorted"))

        let afterWrite = try #require(
            failures["PantryRepository: watchAll emits the new state after a write"])
        #expect(afterWrite.message == "expected another element, but stream finished")
        #expect(failures["PantryRepository: an empty pantry reads []"] == nil)
    }

    @Test("a stream that never emits times out instead of hanging")
    func silentStream() async throws {
        let failures = await failingChecks(
            RepositoryContracts.pantry(streamTimeout: Self.quick)
        ) { ForgetfulPantry(silent: true) as any PantryRepository }
        let first = try #require(
            failures["PantryRepository: watchAll first emits an empty repository as []"])
        #expect(first.message.hasPrefix("no stream element within"))
    }

    @Test("a stream that throws is reported with its error")
    func throwingStream() async throws {
        let failures = await failingChecks(
            RepositoryContracts.pantry(streamTimeout: Self.quick)
        ) { ForgetfulPantry(streamError: StorageFault()) as any PantryRepository }
        let first = try #require(
            failures["PantryRepository: watchAll first emits an empty repository as []"])
        #expect(first.message == "expected another element, but stream threw StorageFault()")
    }

    @Test("storage errors and factory errors become failures, not crashes")
    func unexpectedErrors() async throws {
        let check = try #require(RepositoryContracts.seedState().first)
        let expected = ContractFailure(
            check: check.name, message: "unexpected error: StorageFault()", location: "")
        await #expect(throws: expected) {
            try await check.run(against: { throw StorageFault() })
        }
        #expect(expected.description == "\(check.name): unexpected error: StorageFault()")
    }

    @Test("a shopping list that sorts by id breaks list order")
    func sortedShoppingList() async throws {
        let failures = await failingChecks(
            RepositoryContracts.shopping(streamTimeout: Self.quick)
        ) { SortedShopping() as any ShoppingRepository }
        let order = failures[
            "ShoppingRepository: all() keeps first-insertion order and every field"]
        #expect(order != nil)
        #expect(failures["ShoppingRepository: an empty list reads []"] == nil)
    }

    @Test("a recipe book whose insertMissing overwrites is caught")
    func overwritingRecipes() async throws {
        let failures = await failingChecks(
            RepositoryContracts.recipes(streamTimeout: Self.quick)
        ) { OverwritingRecipes() as any RecipeRepository }
        let overwrite = try #require(
            failures["RecipeRepository: insertMissing never overwrites an existing recipe"])
        #expect(overwrite.message.hasPrefix("inserted ids: expected"))
    }

    @Test("a meal log that accepts duplicate ids is caught")
    func duplicateMealLogs() async throws {
        let failures = await failingChecks(
            RepositoryContracts.mealLogs(streamTimeout: Self.quick)
        ) { DuplicatingMealLogs() as any MealLogRepository }
        let duplicate = try #require(
            failures["MealLogRepository: add rejects a duplicate id and keeps the original"])
        #expect(duplicate.message == "second add: expected duplicateId(\"a\"), nothing thrown")
    }

    @Test("a recipe book that throws the wrong error is caught")
    func wrongError() async throws {
        let failures = await failingChecks(
            RepositoryContracts.recipes(streamTimeout: Self.quick)
        ) { OverwritingRecipes() as any RecipeRepository }
        let flags = try #require(
            failures["RecipeRepository: flag setters throw notFound for an unknown id"])
        #expect(flags.message == "setFavorite: expected notFound(\"ghost\"), got StorageFault()")
    }
}

/// A storage failure raised by the broken adapters.
private struct StorageFault: Error, Equatable {}

/// Drops every write; its stream emits `[]` once and finishes (or never
/// emits, or throws).
private struct ForgetfulPantry: PantryRepository {
    var silent = false
    var streamError: StorageFault?

    func all() async -> [PantryItem] { [] }
    func setLevels(_ items: [PantryItem]) async {}
    func delete(ingredientIds: Set<String>) async {}
    func watchAll() -> AsyncThrowingStream<[PantryItem], any Error> {
        let (stream, continuation) = AsyncThrowingStream<[PantryItem], any Error>.makeStream()
        if let streamError {
            continuation.finish(throwing: streamError)
        } else if !silent {
            continuation.yield([])
            continuation.finish()
        }
        return stream
    }
}

/// Returns the list sorted by id instead of in insertion order.
private struct SortedShopping: ShoppingRepository {
    let base = InMemoryShoppingRepository()

    func all() async -> [ShoppingItem] { await base.all().sorted { $0.id < $1.id } }
    func watchAll() -> AsyncThrowingStream<[ShoppingItem], any Error> { base.watchAll() }
    func upsert(_ items: [ShoppingItem]) async { await base.upsert(items) }
    func setChecked(_ isChecked: Bool, forItemWithId id: String) async throws {
        try await base.setChecked(isChecked, forItemWithId: id)
    }
    func delete(ids: Set<String>) async { await base.delete(ids: ids) }
}

/// `insertMissing` overwrites like `upsert`; flag setters throw a storage
/// error for unknown ids.
private struct OverwritingRecipes: RecipeRepository {
    let base = InMemoryRecipeRepository()

    func all() async -> [Recipe] { await base.all() }
    func watchAll() -> AsyncThrowingStream<[Recipe], any Error> { base.watchAll() }
    func recipe(withId id: String) async -> Recipe? { await base.recipe(withId: id) }
    func upsert(_ recipes: [Recipe]) async { await base.upsert(recipes) }
    func insertMissing(_ recipes: [Recipe]) async -> [String] {
        await base.upsert(recipes)
        return Set(recipes.map(\.id)).sorted()
    }
    func setFavorite(_ isFavorite: Bool, forRecipeWithId id: String) async throws {
        guard await base.recipe(withId: id) != nil else { throw StorageFault() }
        try await base.setFavorite(isFavorite, forRecipeWithId: id)
    }
    func setHidden(_ isHidden: Bool, forRecipeWithId id: String) async throws {
        try await base.setHidden(isHidden, forRecipeWithId: id)
    }
    func delete(id: String) async { await base.delete(id: id) }
}

/// Silently replaces a log with a duplicate id instead of throwing.
private struct DuplicatingMealLogs: MealLogRepository {
    let base = InMemoryMealLogRepository()

    func all() async -> [MealLog] { await base.all() }
    func watchAll() -> AsyncThrowingStream<[MealLog], any Error> { base.watchAll() }
    func add(_ log: MealLog) async { await base.table.upsert([log]) }
}
