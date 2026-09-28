import Foundation
import KyaCore

/// The shared `watchAll()` stream contract, instantiated per repository.
enum ObservationChecks {
    /// Stream checks for one repository type.
    ///
    /// - Parameters:
    ///   - prefix: The protocol name, prepended to every check name.
    ///   - timeout: How long to wait for each stream element.
    ///   - observe: Calls the repository's `watchAll()`.
    ///   - write: Performs one sample write on an empty repository.
    ///   - isWritten: Whether a snapshot reflects exactly that write.
    /// - Returns: The checks.
    static func checks<Repository: Sendable, Row: Sendable>(
        _ prefix: String,
        timeout: Duration,
        observe: @escaping @Sendable (Repository) -> AsyncThrowingStream<[Row], any Error>,
        write: @escaping @Sendable (Repository) async throws -> Void,
        isWritten: @escaping @Sendable ([Row]) -> Bool
    ) -> [ContractCheck<Repository>] {
        [
            ContractCheck("\(prefix): watchAll first emits an empty repository as []") { repo in
                let probe = StreamProbe(observe(repo), timeout: timeout)
                let first = try await probe.next()
                try expect(first.isEmpty, "first element should be [], got \(first)")
            },
            ContractCheck("\(prefix): watchAll first emits the state at subscription") { repo in
                try await write(repo)
                let probe = StreamProbe(observe(repo), timeout: timeout)
                let first = try await probe.next()
                try expect(isWritten(first), "first element should reflect the write: \(first)")
            },
            ContractCheck("\(prefix): watchAll emits the new state after a write") { repo in
                let probe = StreamProbe(observe(repo), timeout: timeout)
                _ = try await probe.next()
                try await write(repo)
                try await probe.next(where: isWritten)
            },
            ContractCheck("\(prefix): each watchAll call returns an independent stream") { repo in
                let first = StreamProbe(observe(repo), timeout: timeout)
                let second = StreamProbe(observe(repo), timeout: timeout)
                _ = try await first.next()
                _ = try await second.next()
                try await write(repo)
                try await first.next(where: isWritten)
                try await second.next(where: isWritten)
            },
            ContractCheck("\(prefix): a cancelled observer never blocks writes") { repo in
                let stream = observe(repo)
                let consumer = Task {
                    for try await _ in stream {}
                }
                consumer.cancel()
                _ = await consumer.result
                try await write(repo)
                let probe = StreamProbe(observe(repo), timeout: timeout)
                let first = try await probe.next()
                try expect(isWritten(first), "write after cancellation was lost: \(first)")
            },
        ]
    }
}

/// Fixed sample values for contract checks. Dates are absolute instants, so
/// the checks are time-zone independent.
enum Fixtures {
    static func instant(_ offset: TimeInterval) -> Date {
        Date(timeIntervalSince1970: 1_790_000_000 + offset)
    }

    static func ingredient(
        _ id: String, name: String? = nil, isUserCreated: Bool = false
    ) -> Ingredient {
        Ingredient(
            id: id, name: name ?? id, aliases: ["\(id) alias"], category: .sabzi, role: .core,
            buyFrom: .sabziwala, shelfLifeDays: 7, isUserCreated: isUserCreated)
    }

    static func pantry(_ id: String, _ level: StockLevel, at offset: TimeInterval = 0)
        -> PantryItem
    {
        PantryItem(ingredientId: id, level: level, updatedAt: instant(offset))
    }

    static func recipe(_ id: String, name: String? = nil) -> Recipe {
        Recipe(
            id: id,
            name: name ?? id,
            mealTypes: [.dinner, .lunch],
            minutes: 20,
            base: .roti,
            ingredients: [
                RecipeIngredient(ingredientId: "onion", quantityText: "1"),
                RecipeIngredient(ingredientId: "jeera", quantityText: "1 tsp", isOptional: true),
            ],
            steps: ["Chop", "Cook"],
            tags: DishTags(
                region: .north, dishType: .curry, flavours: [.spicy, .tangy],
                heaviness: .medium, protein: .vegOnly),
            source: .seed,
            imageAsset: "images/\(id).webp"
        )
    }

    static func mealLog(_ id: String, at offset: TimeInterval) -> MealLog {
        MealLog(id: id, recipeId: "poha", mealType: .breakfast, cookedAt: instant(offset))
    }

    static func swipe(
        _ id: String, at offset: TimeInterval, action: SwipeAction = .right,
        undoes: String? = nil
    ) -> SwipeEvent {
        SwipeEvent(
            id: id, recipeId: "poha", action: action, mode: .craving, at: instant(offset),
            deckSeed: 42, undoesEventId: undoes)
    }

    static func shopping(_ id: String, _ ingredientId: String, checked: Bool = false) throws
        -> ShoppingItem
    {
        try ShoppingItem(
            id: id, ingredientId: ingredientId, reason: .out, isChecked: checked,
            createdAt: instant(0))
    }

    static func customShopping(_ id: String, _ name: String) throws -> ShoppingItem {
        try ShoppingItem(
            id: id, customName: name, reason: .recipe, recipeId: "poha", isChecked: false,
            createdAt: instant(60))
    }
}

/// Field-by-field comparison for ``Ingredient`` lists (`==` compares ids only).
func expectIdentical(
    _ actual: [Ingredient], _ expected: [Ingredient], _ what: String,
    file: StaticString = #fileID, line: UInt = #line
) throws {
    let same =
        actual.count == expected.count
        && zip(actual, expected).allSatisfy { $0.isIdentical(to: $1) }
    try expect(same, "\(what): expected \(expected), got \(actual)", file: file, line: line)
}

/// Field-by-field comparison for ``Recipe`` lists (`==` compares ids only).
func expectIdentical(
    _ actual: [Recipe], _ expected: [Recipe], _ what: String,
    file: StaticString = #fileID, line: UInt = #line
) throws {
    let same =
        actual.count == expected.count
        && zip(actual, expected).allSatisfy { $0.isIdentical(to: $1) }
    try expect(same, "\(what): expected \(expected), got \(actual)", file: file, line: line)
}
