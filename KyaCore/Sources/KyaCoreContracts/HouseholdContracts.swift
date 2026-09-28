import Foundation
import KyaCore

private typealias F = Fixtures

extension RepositoryContracts {
    /// Every ``PantryRepository`` check.
    ///
    /// - Parameter streamTimeout: How long to wait for each `watchAll()` element.
    /// - Returns: The checks, each to run against an empty repository.
    public static func pantry(
        streamTimeout: Duration = defaultStreamTimeout
    ) -> [ContractCheck<any PantryRepository>] {
        let prefix = "PantryRepository"
        return [
            ContractCheck("\(prefix): an empty pantry reads []") { repo in
                try expectEqual(try await repo.all(), [], "all()")
            },
            ContractCheck("\(prefix): all() is sorted by ingredientId with every field kept") {
                repo in
                let expiring = F.pantry("b", .low, at: 60)
                    .withExpiresOn(F.instant(86_400)).copy(expiryIsEstimated: true)
                try await repo.setLevels([F.pantry("c", .out), expiring, F.pantry("a", .plenty)])
                try expectEqual(
                    try await repo.all(), [F.pantry("a", .plenty), expiring, F.pantry("c", .out)],
                    "all()")
            },
            ContractCheck("\(prefix): setLevels keeps one record per ingredient") { repo in
                let expiring = F.pantry("a", .plenty).withExpiresOn(F.instant(86_400))
                try await repo.setLevels([expiring, F.pantry("b", .plenty)])
                try await repo.setLevels([F.pantry("a", .out, at: 120)])
                try expectEqual(
                    try await repo.all(), [F.pantry("a", .out, at: 120), F.pantry("b", .plenty)],
                    "all()")
            },
            ContractCheck("\(prefix): setLevels with a repeated id keeps the last one") { repo in
                try await repo.setLevels([F.pantry("a", .plenty), F.pantry("a", .low)])
                try expectEqual(try await repo.all(), [F.pantry("a", .low)], "all()")
            },
            ContractCheck("\(prefix): setLevels([]) changes nothing") { repo in
                try await repo.setLevels([F.pantry("a", .low)])
                try await repo.setLevels([])
                try expectEqual(try await repo.all(), [F.pantry("a", .low)], "all()")
            },
            ContractCheck("\(prefix): delete removes records and ignores unknown ids") { repo in
                try await repo.setLevels([
                    F.pantry("a", .low), F.pantry("b", .plenty), F.pantry("c", .out),
                ])
                try await repo.delete(ingredientIds: ["b", "ghost"])
                try expectEqual(
                    try await repo.all(), [F.pantry("a", .low), F.pantry("c", .out)], "all()")
                try await repo.delete(ingredientIds: [])
                try expectEqual(
                    try await repo.all().map(\.ingredientId), ["a", "c"], "after delete([])")
            },
        ]
            + ObservationChecks.checks(
                prefix, timeout: streamTimeout,
                observe: { $0.watchAll() },
                write: { try await $0.setLevels([F.pantry("a", .low)]) },
                isWritten: { $0 == [F.pantry("a", .low)] })
    }

    /// Every ``ShoppingRepository`` check.
    ///
    /// - Parameter streamTimeout: How long to wait for each `watchAll()` element.
    /// - Returns: The checks, each to run against an empty repository.
    public static func shopping(
        streamTimeout: Duration = defaultStreamTimeout
    ) -> [ContractCheck<any ShoppingRepository>] {
        let prefix = "ShoppingRepository"
        return [
            ContractCheck("\(prefix): an empty list reads []") { repo in
                try expectEqual(try await repo.all(), [], "all()")
            },
            ContractCheck("\(prefix): all() keeps first-insertion order and every field") {
                repo in
                let custom = try F.customShopping("a", "Birthday candles")
                try await repo.upsert([try F.shopping("z", "onion"), custom])
                try await repo.upsert([try F.shopping("m", "paneer", checked: true)])
                try expectEqual(
                    try await repo.all(),
                    [
                        try F.shopping("z", "onion"), custom,
                        try F.shopping("m", "paneer", checked: true),
                    ],
                    "all()")
            },
            ContractCheck("\(prefix): re-upserting an id replaces it in place") { repo in
                try await repo.upsert([try F.shopping("a", "onion"), try F.shopping("b", "salt")])
                let replaced = try F.customShopping("a", "Red onions")
                try await repo.upsert([replaced])
                try expectEqual(
                    try await repo.all(), [replaced, try F.shopping("b", "salt")], "all()")
            },
            ContractCheck("\(prefix): upsert with a repeated id keeps the last, first position") {
                repo in
                try await repo.upsert([
                    try F.shopping("a", "onion"), try F.shopping("b", "salt"),
                    try F.shopping("a", "paneer"),
                ])
                try expectEqual(
                    try await repo.all(),
                    [try F.shopping("a", "paneer"), try F.shopping("b", "salt")],
                    "all()")
            },
            ContractCheck("\(prefix): setChecked changes only isChecked") { repo in
                try await repo.upsert([try F.shopping("a", "onion"), try F.shopping("b", "salt")])
                try await repo.setChecked(true, forItemWithId: "a")
                try expectEqual(
                    try await repo.all(),
                    [try F.shopping("a", "onion", checked: true), try F.shopping("b", "salt")],
                    "after ticking")
                try await repo.setChecked(false, forItemWithId: "a")
                try expectEqual(
                    try await repo.all(),
                    [try F.shopping("a", "onion"), try F.shopping("b", "salt")],
                    "after unticking")
            },
            ContractCheck("\(prefix): setChecked throws notFound for an unknown id") { repo in
                try await expectError(RepositoryError.notFound("ghost"), "setChecked") {
                    try await repo.setChecked(true, forItemWithId: "ghost")
                }
                try expectEqual(try await repo.all(), [], "all()")
            },
            ContractCheck("\(prefix): delete removes ids, ignores unknown ones, keeps order") {
                repo in
                try await repo.upsert([
                    try F.shopping("a", "onion"), try F.shopping("b", "salt"),
                    try F.shopping("c", "paneer"),
                ])
                try await repo.delete(ids: ["b", "ghost"])
                try expectEqual(
                    try await repo.all(),
                    [try F.shopping("a", "onion"), try F.shopping("c", "paneer")],
                    "all()")
                try await repo.delete(ids: [])
                try expectEqual(try await repo.all().map(\.id), ["a", "c"], "after delete([])")
            },
        ]
            + ObservationChecks.checks(
                prefix, timeout: streamTimeout,
                observe: { $0.watchAll() },
                write: { try await $0.upsert([try F.shopping("a", "onion")]) },
                isWritten: { $0.map(\.id) == ["a"] })
    }

    /// Every ``SeedStateRepository`` check.
    ///
    /// - Returns: The checks, each to run against an empty repository.
    public static func seedState() -> [ContractCheck<any SeedStateRepository>] {
        let prefix = "SeedStateRepository"
        return [
            ContractCheck("\(prefix): a fresh store has no seed version") { repo in
                try expectEqual(try await repo.seedVersion(), nil, "seedVersion()")
            },
            ContractCheck("\(prefix): setSeedVersion stores the latest value") { repo in
                try await repo.setSeedVersion(1)
                try expectEqual(try await repo.seedVersion(), 1, "after setting 1")
                try await repo.setSeedVersion(3)
                try expectEqual(try await repo.seedVersion(), 3, "after setting 3")
            },
        ]
    }
}
