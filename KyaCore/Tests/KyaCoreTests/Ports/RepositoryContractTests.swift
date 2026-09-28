import KyaCore
import KyaCoreContracts
import Testing

/// Runs the shared `KyaCoreContracts` suite against the in-memory reference
/// implementation. The app's SwiftData adapter tests run the same checks with
/// their own `RepositorySet` factory.
@Suite("Repository contract: in-memory reference")
struct RepositoryContractTests {
    @Test(arguments: RepositoryContracts.all())
    func contract(_ check: ContractCheck<RepositorySet>) async throws {
        try await check.run(against: { makeInMemoryRepositorySet() })
    }

    @Test("the full suite covers every repository and reports no failures")
    func fullSuite() async {
        let checks = RepositoryContracts.all()
        let prefixes = Set(checks.map { $0.name.prefix { $0 != ":" } })
        #expect(
            prefixes == [
                "IngredientRepository", "PantryRepository", "RecipeRepository",
                "MealLogRepository", "SwipeEventRepository", "ShoppingRepository",
                "SeedStateRepository", "BackupRepository",
            ])
        #expect(Set(checks.map(\.name)).count == checks.count, "check names must be unique")
        let failures = await ContractCheck.failures(of: checks) { makeInMemoryRepositorySet() }
        #expect(failures == [])
    }
}
