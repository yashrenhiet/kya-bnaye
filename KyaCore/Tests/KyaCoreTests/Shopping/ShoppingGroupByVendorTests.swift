import Foundation
import KyaCore
import Testing

@Suite("ShoppingListBuilder.groupByVendor")
struct ShoppingGroupByVendorTests {
    private let builder = ShoppingListBuilder()
    private let now: Date

    init() throws {
        now = try ShoppingFixtures.now()
    }

    private func item(_ id: String, ingredientId: String? = nil, custom: String? = nil) throws
        -> ShoppingItem
    {
        try ShoppingItem(
            id: id, ingredientId: ingredientId, customName: custom, reason: .manual,
            isChecked: false, createdAt: now)
    }

    private func group(_ items: [ShoppingItem]) -> [ShoppingVendorGroup] {
        builder.groupByVendor(items: items, ingredientsById: ShoppingFixtures.catalog)
    }

    private func items(_ groups: [ShoppingVendorGroup], _ vendor: BuyFrom) -> [ShoppingItem]? {
        groups.first { $0.vendor == vendor }?.items
    }

    @Test("empty items yield all four vendors with empty lists")
    func emptyItems() {
        let grouped = group([])
        #expect(grouped.map(\.vendor) == BuyFrom.allCases)
        let isEveryGroupEmpty = grouped.allSatisfy { $0.items.isEmpty }
        #expect(isEveryGroupEmpty)
    }

    @Test("maps each item to its ingredient vendor")
    func mapsVendors() throws {
        let potato = try item("1", ingredientId: "potato")
        let paneer = try item("2", ingredientId: "paneer")
        let salt = try item("3", ingredientId: "salt")
        let dragon = try item("4", ingredientId: "dragonfruit")

        let grouped = group([potato, paneer, salt, dragon])

        #expect(
            grouped == [
                ShoppingVendorGroup(vendor: .sabziwala, items: [potato]),
                ShoppingVendorGroup(vendor: .kirana, items: [salt]),
                ShoppingVendorGroup(vendor: .dairy, items: [paneer]),
                ShoppingVendorGroup(vendor: .other, items: [dragon]),
            ])
    }

    @Test("custom-name items go to other")
    func customGoesToOther() throws {
        let candles = try item("1", custom: "Birthday candles")
        #expect(items(group([candles]), .other) == [candles])
    }

    @Test("unknown ingredient ids go to other")
    func unknownGoesToOther() throws {
        let ghost = try item("1", ingredientId: "ghost")
        let grouped = group([ghost])
        #expect(items(grouped, .other) == [ghost])
        #expect(items(grouped, .kirana) == [])
    }

    @Test("preserves input order within a vendor")
    func preservesOrder() throws {
        let onion = try item("1", ingredientId: "onion")
        let potato = try item("2", ingredientId: "potato")
        #expect(items(group([onion, potato]), .sabziwala) == [onion, potato])
    }

    @Test("every input item appears in exactly one group")
    func partition() throws {
        let input = [
            try item("1", ingredientId: "potato"),
            try item("2", ingredientId: "ghost"),
            try item("3", custom: "Foil"),
            try item("4", ingredientId: "jeera"),
        ]
        let flattened = group(input).flatMap(\.items)
        #expect(flattened.count == input.count)
        #expect(Set(flattened) == Set(input))
    }
}
