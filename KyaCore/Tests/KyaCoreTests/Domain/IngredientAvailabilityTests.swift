import Foundation
import KyaCore
import Testing

@Suite("IngredientAvailability")
struct IngredientAvailabilityTests {
    private let updatedAt: Date

    init() throws {
        updatedAt = try TestDates.local(2025, 6)
    }

    private func pantryWith(_ id: String, _ level: StockLevel) -> [String: PantryItem] {
        [id: PantryItem(ingredientId: id, level: level, updatedAt: updatedAt)]
    }

    private func available(
        _ role: IngredientRole?,
        _ pantry: [String: PantryItem],
        id: String = "x"
    ) -> Bool {
        IngredientAvailability.isAvailable(ingredientId: id, role: role, pantry: pantry)
    }

    // MARK: staple role

    @Test("staple: available with no pantry record at all")
    func stapleNoRecord() {
        #expect(available(.staple, [:]))
    }

    @Test("staple: available when plenty or low")
    func staplePlentyOrLow() {
        #expect(available(.staple, pantryWith("x", .plenty)))
        #expect(available(.staple, pantryWith("x", .low)))
    }

    @Test("staple: unavailable only when explicitly marked out")
    func stapleOut() {
        #expect(!available(.staple, pantryWith("x", .out)))
    }

    @Test("staple: ignores records belonging to other ingredients")
    func stapleOtherRecord() {
        #expect(available(.staple, pantryWith("y", .out)))
    }

    // MARK: optional role (never counts as missing)

    @Test("optional: available at every level", arguments: StockLevel.allCases)
    func optionalAtLevel(level: StockLevel) {
        #expect(available(.optional, pantryWith("x", level)))
    }

    @Test("optional: available with no pantry record at all")
    func optionalNoRecord() {
        #expect(available(.optional, [:]))
    }

    // MARK: core, flavor and unknown (nil) roles

    static let strictRoles: [IngredientRole?] = [.core, .flavor, nil]

    @Test("strict roles: unavailable with no pantry record (never bought)", arguments: strictRoles)
    func strictNoRecord(role: IngredientRole?) {
        #expect(!available(role, [:]))
    }

    @Test("strict roles: available when plenty", arguments: strictRoles)
    func strictPlenty(role: IngredientRole?) {
        #expect(available(role, pantryWith("x", .plenty)))
    }

    @Test("strict roles: low still counts as available", arguments: strictRoles)
    func strictLow(role: IngredientRole?) {
        #expect(available(role, pantryWith("x", .low)))
    }

    @Test("strict roles: unavailable when out", arguments: strictRoles)
    func strictOut(role: IngredientRole?) {
        #expect(!available(role, pantryWith("x", .out)))
    }

    @Test(
        "strict roles: a record for a different ingredient does not count", arguments: strictRoles)
    func strictOtherRecord(role: IngredientRole?) {
        #expect(!available(role, pantryWith("y", .plenty)))
    }

    @Test("matches the ingredient id exactly, never by substring")
    func exactIdMatch() {
        let pantry = pantryWith("rice_flour", .plenty)

        #expect(!available(.core, pantry, id: "rice"))
        #expect(available(.core, pantry, id: "rice_flour"))
    }

    // MARK: recipe-line variant

    @Test("an isOptional line never counts as missing, whatever the role")
    func optionalLine() {
        let line = RecipeIngredient(ingredientId: "x", quantityText: "some", isOptional: true)
        for role in Self.strictRoles + [.staple] {
            #expect(IngredientAvailability.isAvailable(line, role: role, pantry: [:]))
            #expect(
                IngredientAvailability.isAvailable(line, role: role, pantry: pantryWith("x", .out)))
        }
    }

    @Test("a required line follows the ingredient-level rule")
    func requiredLine() {
        let line = RecipeIngredient(ingredientId: "x", quantityText: "1")
        #expect(!IngredientAvailability.isAvailable(line, role: .core, pantry: [:]))
        #expect(
            IngredientAvailability.isAvailable(line, role: .core, pantry: pantryWith("x", .low)))
        #expect(IngredientAvailability.isAvailable(line, role: .optional, pantry: [:]))
        #expect(
            !IngredientAvailability.isAvailable(line, role: .staple, pantry: pantryWith("x", .out)))
    }
}
