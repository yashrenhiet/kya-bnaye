import Foundation
import KyaCore

/// The executable form of the repository contract documented on the
/// `KyaCore` port protocols. Every adapter (the in-memory reference in
/// `KyaCoreTests`, the app's SwiftData adapters) must pass every check.
///
/// Each factory returns checks to run against a **fresh, empty** subject; see
/// ``ContractCheck/run(against:)`` and ``ContractCheck/failures(of:against:)``.
public enum RepositoryContracts {
    /// The default wait for one `watchAll()` element before a check fails,
    /// generous enough for a loaded CI machine.
    public static let defaultStreamTimeout: Duration = .seconds(5)

    /// Every check in this contract, over a whole ``RepositorySet``: each
    /// per-repository suite (run against the matching member) plus
    /// ``backup(streamTimeout:)``.
    ///
    /// - Parameter streamTimeout: How long to wait for each `watchAll()` element.
    /// - Returns: The checks, each to run against an empty set.
    public static func all(
        streamTimeout: Duration = defaultStreamTimeout
    ) -> [ContractCheck<RepositorySet>] {
        let perRepository: [[ContractCheck<RepositorySet>]] = [
            ingredients(streamTimeout: streamTimeout).map { $0.pulledBack { $0.ingredients } },
            pantry(streamTimeout: streamTimeout).map { $0.pulledBack { $0.pantry } },
            recipes(streamTimeout: streamTimeout).map { $0.pulledBack { $0.recipes } },
            mealLogs(streamTimeout: streamTimeout).map { $0.pulledBack { $0.mealLogs } },
            swipeEvents(streamTimeout: streamTimeout).map { $0.pulledBack { $0.swipeEvents } },
            shopping(streamTimeout: streamTimeout).map { $0.pulledBack { $0.shopping } },
            seedState().map { $0.pulledBack { $0.seedState } },
        ]
        return perRepository.flatMap { $0 } + backup(streamTimeout: streamTimeout)
    }
}
