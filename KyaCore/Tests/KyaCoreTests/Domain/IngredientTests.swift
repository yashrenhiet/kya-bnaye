import KyaCore
import Testing

@Suite("Ingredient")
struct IngredientTests {
    private let potato = Ingredient(
        id: "potato",
        name: "Potato",
        aliases: ["aloo", "batata"],
        category: .sabzi,
        role: .core,
        buyFrom: .sabziwala,
        shelfLifeDays: 21
    )

    @Test("aliases default to empty, shelf life nil, not user-made")
    func constructionDefaults() {
        let salt = Ingredient(
            id: "salt", name: "Salt", category: .masala, role: .staple, buyFrom: .kirana)

        #expect(salt.aliases.isEmpty)
        #expect(salt.shelfLifeDays == nil)
        #expect(!salt.isUserCreated)
    }

    // MARK: equality

    @Test("is identity-by-id: same id with different fields is equal")
    func identityById() {
        let renamed = potato.copy(
            name: "Aloo",
            aliases: [],
            category: .other,
            role: .optional,
            buyFrom: .other,
            isUserCreated: true
        ).withShelfLifeDays(1)

        #expect(renamed == potato)
        #expect(renamed.hashValue == potato.hashValue)
        #expect(!renamed.isIdentical(to: potato))
    }

    @Test("different ids are not equal even if every other field is")
    func differentIds() {
        #expect(potato.copy(id: "sweet_potato") != potato)
    }

    @Test("ids are compared case-sensitively")
    func caseSensitiveIds() {
        #expect(potato.copy(id: "Potato") != potato)
    }

    @Test("deduplicates by id inside a Set")
    func setDeduplicates() {
        let set: Set = [potato, potato.copy(name: "Batata")]

        #expect(set.count == 1)
    }

    @Test("isIdentical compares every field")
    func isIdentical() {
        #expect(potato.isIdentical(to: potato.copy()))
        #expect(!potato.isIdentical(to: potato.copy(name: "Aloo")))
        #expect(!potato.isIdentical(to: potato.copy(aliases: ["aloo"])))
        #expect(!potato.isIdentical(to: potato.copy(category: .other)))
        #expect(!potato.isIdentical(to: potato.copy(role: .flavor)))
        #expect(!potato.isIdentical(to: potato.copy(buyFrom: .kirana)))
        #expect(!potato.isIdentical(to: potato.withShelfLifeDays(22)))
        #expect(!potato.isIdentical(to: potato.copy(isUserCreated: true)))
        #expect(!potato.isIdentical(to: potato.copy(id: "aloo")))
    }

    // MARK: copy

    @Test("copy with no arguments preserves every field")
    func copyPreserves() {
        let copy = potato.copy()

        #expect(copy.id == potato.id)
        #expect(copy.name == potato.name)
        #expect(copy.aliases == potato.aliases)
        #expect(copy.category == potato.category)
        #expect(copy.role == potato.role)
        #expect(copy.buyFrom == potato.buyFrom)
        #expect(copy.shelfLifeDays == potato.shelfLifeDays)
        #expect(copy.isUserCreated == potato.isUserCreated)
    }

    @Test("copy replaces only the fields that are passed")
    func copyReplaces() {
        let copy = potato.copy(name: "Aloo", role: .flavor).withShelfLifeDays(30)

        #expect(copy.name == "Aloo")
        #expect(copy.role == .flavor)
        #expect(copy.shelfLifeDays == 30)
        #expect(copy.aliases == ["aloo", "batata"])
        #expect(copy.category == .sabzi)
        #expect(copy.buyFrom == .sabziwala)
        #expect(!copy.isUserCreated)
    }

    @Test("copy does not mutate the original")
    func copyDoesNotMutate() {
        _ = potato.copy(name: "Changed").withShelfLifeDays(2)

        #expect(potato.name == "Potato")
        #expect(potato.shelfLifeDays == 21)
    }

    @Test("can clear shelfLifeDays back to nil")
    func clearShelfLife() {
        let cleared = potato.withShelfLifeDays(nil)

        #expect(cleared.shelfLifeDays == nil)
        #expect(cleared.isIdentical(to: potato.withShelfLifeDays(nil)))
        #expect(potato.copy(name: "X").shelfLifeDays == 21)
    }

    @Test("description identifies the ingredient by id")
    func description() {
        #expect(potato.description == "Ingredient(potato)")
    }
}
