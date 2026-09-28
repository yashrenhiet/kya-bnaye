import Foundation
import KyaCore
import Testing

@Suite("ShoppingItem")
struct ShoppingItemTests {
    private let createdAt: Date

    init() throws {
        createdAt = try TestDates.local(2025, 6, 1, 10)
    }

    private func catalogItem(
        id: String = "s1",
        ingredientId: String? = "onion",
        customName: String? = nil,
        reason: ShoppingReason = .out,
        recipeId: String? = nil,
        isChecked: Bool = false,
        at: Date? = nil
    ) throws -> ShoppingItem {
        try ShoppingItem(
            id: id,
            ingredientId: ingredientId,
            customName: customName,
            reason: reason,
            recipeId: recipeId,
            isChecked: isChecked,
            createdAt: at ?? createdAt
        )
    }

    // MARK: invariant: ingredientId or customName is required

    @Test("throws when both ingredientId and customName are nil")
    func rejectsBothNil() {
        #expect(throws: ShoppingItemError.missingIngredientAndCustomName) {
            try catalogItem(ingredientId: nil)
        }
    }

    @Test("accepts a catalog-only item")
    func catalogOnly() throws {
        let item = try catalogItem()

        #expect(item.ingredientId == "onion")
        #expect(item.customName == nil)
    }

    @Test("accepts a free-typed item with no ingredientId")
    func freeTyped() throws {
        let item = try catalogItem(
            ingredientId: nil, customName: "birthday candles", reason: .manual)

        #expect(item.ingredientId == nil)
        #expect(item.customName == "birthday candles")
    }

    // MARK: displayName

    @Test("resolves a catalog item through the supplied resolver")
    func displayNameResolves() throws {
        var requested: [String] = []
        let name = try catalogItem().displayName { id in
            requested.append(id)
            return "Onion"
        }

        #expect(name == "Onion")
        #expect(requested == ["onion"])
    }

    @Test("uses customName without calling the resolver")
    func displayNameCustom() throws {
        let item = try catalogItem(ingredientId: nil, customName: "Birthday candles")
        var calls = 0

        let name = item.displayName { _ in
            calls += 1
            return "wrong"
        }

        #expect(name == "Birthday candles")
        #expect(calls == 0)
    }

    @Test("customName wins when both are set")
    func displayNameBoth() throws {
        let item = try catalogItem(customName: "Pyaaz")

        #expect(item.displayName { _ in "Onion" } == "Pyaaz")
    }

    // MARK: equality

    @Test("items with identical fields are equal with equal hashes")
    func equalItems() throws {
        let a = try catalogItem(reason: .recipe, recipeId: "palak_paneer")
        let b = try catalogItem(reason: .recipe, recipeId: "palak_paneer")

        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test("differs when any single field differs")
    func anyFieldDiffers() throws {
        let base = try catalogItem()

        #expect(try catalogItem(id: "s2") != base)
        #expect(try catalogItem(ingredientId: "garlic") != base)
        #expect(try catalogItem(customName: "Pyaaz") != base)
        #expect(try catalogItem(reason: .low) != base)
        #expect(try catalogItem(recipeId: "poha") != base)
        #expect(try catalogItem(isChecked: true) != base)
        #expect(try catalogItem(at: createdAt.addingTimeInterval(1)) != base)
    }

    @Test("withIsChecked changes only the checked flag")
    func withIsChecked() throws {
        let base = try catalogItem()

        #expect(base.withIsChecked(true) == (try catalogItem(isChecked: true)))
        #expect(base.withIsChecked(true).withIsChecked(false) == base)
    }

    @Test("ShoppingReason covers exactly out, low, recipe, manual")
    func reasons() {
        #expect(ShoppingReason.allCases == [.out, .low, .recipe, .manual])
    }
}
