import Foundation
import KyaCore

private typealias F = Fixtures

extension RepositoryContracts {
    /// Every ``BackupRepository`` check, over a whole ``RepositorySet`` (the
    /// backup must see and replace exactly what the other members read).
    ///
    /// - Parameter streamTimeout: How long to wait for each `watchAll()` element.
    /// - Returns: The checks, each to run against an empty set.
    public static func backup(
        streamTimeout: Duration = defaultStreamTimeout
    ) -> [ContractCheck<RepositorySet>] {
        let prefix = "BackupRepository"
        return [
            ContractCheck("\(prefix): an empty store exports an empty snapshot") { set in
                try expectSame(try await set.backup.exportSnapshot(), RepositorySnapshot())
            },
            ContractCheck("\(prefix): export reads every repository in its order") { set in
                try await populate(set, with: try sample())
                try expectSame(try await set.backup.exportSnapshot(), try sample())
            },
            ContractCheck("\(prefix): replaceAll makes every repository read the snapshot") {
                set in
                let sample = try sample()
                try await set.backup.replaceAll(with: reversed(sample))
                try await expectReads(set, sample)
            },
            ContractCheck("\(prefix): replaceAll wipes rows missing from the snapshot") { set in
                try await populate(set, with: try sample())
                let smaller = RepositorySnapshot(
                    recipes: [F.recipe("r_new")], shoppingItems: [try F.shopping("s_new", "salt")],
                    seedVersion: 7)
                try await set.backup.replaceAll(with: smaller)
                try await expectReads(set, smaller)
            },
            ContractCheck("\(prefix): export, wipe, import restores everything") { set in
                try await populate(set, with: try sample())
                let exported = try await set.backup.exportSnapshot()
                try await set.backup.replaceAll(with: RepositorySnapshot())
                try expectSame(try await set.backup.exportSnapshot(), RepositorySnapshot())
                try await set.backup.replaceAll(with: exported)
                try expectSame(try await set.backup.exportSnapshot(), try sample())
            },
            ContractCheck("\(prefix): restored history stays append-only") { set in
                try await set.backup.replaceAll(with: try sample())
                try await expectError(RepositoryError.duplicateId("m1"), "meal log add") {
                    try await set.mealLogs.add(F.mealLog("m1", at: 999))
                }
                try await expectError(RepositoryError.duplicateId("e1"), "swipe add") {
                    try await set.swipeEvents.add(F.swipe("e1", at: 999))
                }
            },
            ContractCheck("\(prefix): observers see the restored state") { set in
                let sample = try sample()
                let probe = StreamProbe(set.pantry.watchAll(), timeout: streamTimeout)
                _ = try await probe.next()
                try await set.backup.replaceAll(with: sample)
                try await probe.next(where: { $0 == sample.pantryItems })
            },
        ]
    }

    /// A snapshot touching every repository, each list in its documented order.
    private static func sample() throws -> RepositorySnapshot {
        RepositorySnapshot(
            ingredients: [F.ingredient("i1"), F.ingredient("i2", isUserCreated: true)],
            pantryItems: [F.pantry("i1", .low), F.pantry("i2", .out, at: 30)],
            recipes: [F.recipe("r1"), F.recipe("r2").copy(isFavorite: true, isHidden: true)],
            mealLogs: [F.mealLog("m2", at: -60), F.mealLog("m1", at: 0)],
            swipeEvents: [F.swipe("e1", at: 0), F.swipe("e2", at: 0, action: .left)],
            shoppingItems: [
                try F.shopping("s2", "i1", checked: true), try F.customShopping("s1", "Foil"),
            ],
            seedVersion: 2
        )
    }

    /// `snapshot` with every list reversed, so reads must re-sort (the
    /// shopping list excepted, whose order is the snapshot's).
    private static func reversed(_ snapshot: RepositorySnapshot) -> RepositorySnapshot {
        RepositorySnapshot(
            ingredients: snapshot.ingredients.reversed(),
            pantryItems: snapshot.pantryItems.reversed(),
            recipes: snapshot.recipes.reversed(),
            mealLogs: snapshot.mealLogs.reversed(),
            swipeEvents: snapshot.swipeEvents.reversed(),
            shoppingItems: snapshot.shoppingItems,
            seedVersion: snapshot.seedVersion
        )
    }

    /// Writes `snapshot` through the individual repositories.
    private static func populate(_ set: RepositorySet, with snapshot: RepositorySnapshot)
        async throws
    {
        try await set.ingredients.upsert(snapshot.ingredients)
        try await set.pantry.setLevels(snapshot.pantryItems)
        try await set.recipes.upsert(snapshot.recipes)
        for log in snapshot.mealLogs { try await set.mealLogs.add(log) }
        for event in snapshot.swipeEvents { try await set.swipeEvents.add(event) }
        try await set.shopping.upsert(snapshot.shoppingItems)
        if let version = snapshot.seedVersion { try await set.seedState.setSeedVersion(version) }
    }

    /// Checks that every repository reads exactly `expected`.
    private static func expectReads(_ set: RepositorySet, _ expected: RepositorySnapshot)
        async throws
    {
        let actual = RepositorySnapshot(
            ingredients: try await set.ingredients.all(),
            pantryItems: try await set.pantry.all(),
            recipes: try await set.recipes.all(),
            mealLogs: try await set.mealLogs.all(),
            swipeEvents: try await set.swipeEvents.all(),
            shoppingItems: try await set.shopping.all(),
            seedVersion: try await set.seedState.seedVersion()
        )
        try expectSame(actual, expected)
    }

    /// Field-by-field snapshot comparison, reporting the first differing list.
    private static func expectSame(
        _ actual: RepositorySnapshot, _ expected: RepositorySnapshot,
        file: StaticString = #fileID, line: UInt = #line
    ) throws {
        try expectIdentical(
            actual.ingredients, expected.ingredients, "ingredients", file: file, line: line)
        try expectEqual(
            actual.pantryItems, expected.pantryItems, "pantryItems", file: file, line: line)
        try expectIdentical(actual.recipes, expected.recipes, "recipes", file: file, line: line)
        try expectEqual(actual.mealLogs, expected.mealLogs, "mealLogs", file: file, line: line)
        try expectEqual(
            actual.swipeEvents, expected.swipeEvents, "swipeEvents", file: file, line: line)
        try expectEqual(
            actual.shoppingItems, expected.shoppingItems, "shoppingItems", file: file, line: line)
        try expectEqual(
            actual.seedVersion, expected.seedVersion, "seedVersion", file: file, line: line)
    }
}
