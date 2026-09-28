import Foundation
import KyaCore

private typealias F = Fixtures

extension RepositoryContracts {
    /// Every ``MealLogRepository`` check.
    ///
    /// - Parameter streamTimeout: How long to wait for each `watchAll()` element.
    /// - Returns: The checks, each to run against an empty repository.
    public static func mealLogs(
        streamTimeout: Duration = defaultStreamTimeout
    ) -> [ContractCheck<any MealLogRepository>] {
        let prefix = "MealLogRepository"
        return [
            ContractCheck("\(prefix): an empty history reads []") { repo in
                try expectEqual(try await repo.all(), [], "all()")
            },
            ContractCheck("\(prefix): all() is sorted by cookedAt, ties by id") { repo in
                for log in [F.mealLog("b", at: 0), F.mealLog("a", at: 0), F.mealLog("c", at: -10)] {
                    try await repo.add(log)
                }
                try expectEqual(
                    try await repo.all(),
                    [F.mealLog("c", at: -10), F.mealLog("a", at: 0), F.mealLog("b", at: 0)],
                    "all()")
            },
            ContractCheck("\(prefix): add rejects a duplicate id and keeps the original") { repo in
                try await repo.add(F.mealLog("a", at: 0))
                try await expectError(RepositoryError.duplicateId("a"), "second add") {
                    try await repo.add(F.mealLog("a", at: 99))
                }
                try expectEqual(try await repo.all(), [F.mealLog("a", at: 0)], "all()")
            },
        ]
            + ObservationChecks.checks(
                prefix, timeout: streamTimeout,
                observe: { $0.watchAll() },
                write: { try await $0.add(F.mealLog("a", at: 0)) },
                isWritten: { $0 == [F.mealLog("a", at: 0)] })
    }

    /// Every ``SwipeEventRepository`` check.
    ///
    /// - Parameter streamTimeout: How long to wait for each `watchAll()` element.
    /// - Returns: The checks, each to run against an empty repository.
    public static func swipeEvents(
        streamTimeout: Duration = defaultStreamTimeout
    ) -> [ContractCheck<any SwipeEventRepository>] {
        let prefix = "SwipeEventRepository"
        return [
            ContractCheck("\(prefix): an empty log reads []") { repo in
                try expectEqual(try await repo.all(), [], "all()")
            },
            ContractCheck("\(prefix): all() is sorted by time, ties by id, fields kept") { repo in
                let undo = F.swipe("u", at: 5, action: .undo, undoes: "b")
                for event in [F.swipe("b", at: 0), undo, F.swipe("a", at: 0, action: .neverShow)] {
                    try await repo.add(event)
                }
                try expectEqual(
                    try await repo.all(),
                    [F.swipe("a", at: 0, action: .neverShow), F.swipe("b", at: 0), undo],
                    "all()")
            },
            ContractCheck("\(prefix): add rejects a duplicate id and keeps history") { repo in
                try await repo.add(F.swipe("a", at: 0))
                try await expectError(RepositoryError.duplicateId("a"), "second add") {
                    try await repo.add(F.swipe("a", at: 9, action: .left))
                }
                try expectEqual(try await repo.all(), [F.swipe("a", at: 0)], "all()")
            },
            ContractCheck("\(prefix): deleteAll forgets every event") { repo in
                for event in [F.swipe("a", at: 0), F.swipe("u", at: 5, action: .undo, undoes: "a")]
                {
                    try await repo.add(event)
                }
                try await repo.deleteAll()
                try expectEqual(try await repo.all(), [], "all() after deleteAll")
            },
            ContractCheck("\(prefix): deleteAll on an empty log is a no-op") { repo in
                try await repo.deleteAll()
                try expectEqual(try await repo.all(), [], "all()")
            },
            ContractCheck("\(prefix): after deleteAll the log appends again, old ids too") {
                repo in
                try await repo.add(F.swipe("a", at: 0))
                try await repo.deleteAll()
                try await repo.add(F.swipe("a", at: 9, action: .left))
                try expectEqual(try await repo.all(), [F.swipe("a", at: 9, action: .left)], "all()")
            },
            ContractCheck("\(prefix): watchAll delivers the empty log after deleteAll") { repo in
                try await repo.add(F.swipe("a", at: 0))
                let probe = StreamProbe(repo.watchAll(), timeout: streamTimeout)
                try await probe.next(where: { $0 == [F.swipe("a", at: 0)] })
                try await repo.deleteAll()
                try await probe.next(where: \.isEmpty)
            },
        ]
            + ObservationChecks.checks(
                prefix, timeout: streamTimeout,
                observe: { $0.watchAll() },
                write: { try await $0.add(F.swipe("a", at: 0)) },
                isWritten: { $0 == [F.swipe("a", at: 0)] })
    }
}
