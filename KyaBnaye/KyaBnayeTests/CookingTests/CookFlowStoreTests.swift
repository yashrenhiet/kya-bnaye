import Foundation
import KyaCore
import Testing

@testable import KyaBnaye

@Suite("CookFlowStore")
@MainActor
struct CookFlowStoreTests {
    private typealias F = RecipeTestFixtures

    private func store(_ repositories: RepositorySet, calendar: Calendar) -> CookFlowStore {
        CookFlowStore(
            repositories: repositories, now: { F.now }, calendar: { calendar },
            makeId: F.sequentialIds())
    }

    /// Pantry with every Aloo Matar ingredient in stock (peas low) plus paneer.
    private let stocked: [(String, StockLevel)] = [
        ("potato", .plenty), ("peas", .low), ("jeera", .plenty), ("salt", .plenty),
        ("paneer", .plenty),
    ]

    @Test("I made this writes a meal log with the meal slot from the calendar's hour")
    func logsMeal() async throws {
        let repositories = try await F.repositories(pantry: stocked)
        let utc = try F.calendar("UTC")
        let flow = store(repositories, calendar: utc)

        await flow.cook(F.alooMatar)

        let logs = try await repositories.mealLogs.all()
        let hour = utc.component(.hour, from: F.now)
        #expect(
            logs == [
                MealLog(
                    id: "id1", recipeId: "aloo_matar",
                    mealType: RankingContext.mealType(forHour: hour), cookedAt: F.now)
            ])
        #expect(flow.lastLog == logs.first)
        #expect(flow.confirmation == "Aloo Matar added to your history")
    }

    @Test("the used-up sheet lists only the recipe's perishables that are in stock")
    func listsPerishables() async throws {
        let repositories = try await F.repositories(pantry: stocked)
        let flow = store(repositories, calendar: try F.calendar())

        await flow.cook(F.alooMatar)

        #expect(flow.phase == .askingUsedUp)
        #expect(flow.isAskingUsedUp)
        #expect(flow.candidates.map(\.ingredient.id) == ["potato", "peas"])
        #expect(flow.candidates.map(\.currentLevel) == [.plenty, .low])
    }

    @Test("with no perishables at home the meal is logged and no sheet appears")
    func noPerishables() async throws {
        let repositories = try await F.repositories(pantry: [("jeera", .plenty)])
        let flow = store(repositories, calendar: try F.calendar())

        await flow.cook(F.alooMatar)

        #expect(flow.phase == .idle)
        #expect(!flow.isAskingUsedUp)
        #expect(try await repositories.mealLogs.all().count == 1)
    }

    @Test("confirm writes only the tapped levels, in one batch")
    func confirmWrites() async throws {
        let repositories = try await F.repositories(pantry: stocked)
        let flow = store(repositories, calendar: try F.calendar())
        await flow.cook(F.alooMatar)

        flow.choose(.out, for: "potato")
        flow.choose(.low, for: "peas")  // already low: no write
        flow.choose(.out, for: "paneer")  // not a candidate: ignored
        await flow.confirm()

        let pantry = Dictionary(
            uniqueKeysWithValues: try await repositories.pantry.all().map { ($0.ingredientId, $0) })
        #expect(pantry["potato"]?.level == .out)
        #expect(pantry["peas"]?.level == .low)
        #expect(pantry["paneer"]?.level == .plenty)
        #expect(flow.phase == .idle)
        #expect(flow.candidates.isEmpty)
        #expect(flow.confirmation == "Pantry updated")
    }

    @Test("tapping the same level twice clears the choice")
    func toggleChoice() async throws {
        let repositories = try await F.repositories(pantry: stocked)
        let flow = store(repositories, calendar: try F.calendar())
        await flow.cook(F.alooMatar)

        flow.choose(.low, for: "potato")
        flow.choose(.low, for: "potato")
        #expect(flow.choices.isEmpty)
        await flow.confirm()
        #expect(
            try await repositories.pantry.all().first { $0.ingredientId == "potato" }?.level
                == .plenty)
    }

    @Test("skip writes nothing to the pantry")
    func skipWritesNothing() async throws {
        let repositories = try await F.repositories(pantry: stocked)
        let flow = store(repositories, calendar: try F.calendar())
        await flow.cook(F.alooMatar)
        let before = try await repositories.pantry.all()

        flow.choose(.out, for: "potato")
        flow.skip()

        #expect(try await repositories.pantry.all() == before)
        #expect(flow.phase == .idle)
        #expect(try await repositories.mealLogs.all().count == 1)
    }

    @Test("a second cook while the sheet is open is ignored")
    func ignoresReentry() async throws {
        let repositories = try await F.repositories(pantry: stocked)
        let flow = store(repositories, calendar: try F.calendar())
        await flow.cook(F.alooMatar)
        await flow.cook(F.jeeraAloo)
        #expect(try await repositories.mealLogs.all().count == 1)
        #expect(flow.recipe?.id == "aloo_matar")
    }

    @Test("a duplicate log id surfaces an error and opens no sheet")
    func logFailure() async throws {
        let existing = MealLog(id: "dup", recipeId: "x", mealType: .lunch, cookedAt: F.now)
        let repositories = try await F.repositories(pantry: stocked, logs: [existing])
        let flow = CookFlowStore(
            repositories: repositories, now: { F.now }, calendar: { .kyaDefault },
            makeId: { "dup" })

        await flow.cook(F.alooMatar)

        #expect(flow.errorMessage == "Couldn't save that you made Aloo Matar. Please try again.")
        #expect(flow.phase == .idle)
        #expect(try await repositories.mealLogs.all() == [existing])
    }
}
