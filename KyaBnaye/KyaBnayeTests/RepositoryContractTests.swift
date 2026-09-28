import KyaCore
import KyaCoreContracts
import Testing

@testable import KyaBnaye

/// The SwiftData adapters must pass exactly the same executable contract as the in-memory
/// reference implementation in `KyaCoreTests`: every repository, plus the cross-repository
/// backup checks. Each check gets a fresh in-memory store.
@Suite("SwiftData adapters: KyaCore repository contract")
struct RepositoryContractTests {
    @Test(arguments: RepositoryContracts.all())
    func contract(_ check: ContractCheck<RepositorySet>) async throws {
        try await check.run(against: { try SwiftDataStore.inMemory().repositories })
    }
}
