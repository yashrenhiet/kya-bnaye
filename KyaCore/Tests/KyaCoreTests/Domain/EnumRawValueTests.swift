import Foundation
import KyaCore
import Testing

/// Freezes every enum's raw values and case order: they are persisted in seed
/// and backup JSON and must stay byte-identical to the Dart `.name` values.
@Suite("Enum raw values")
struct EnumRawValueTests {
    private func raw<E: CaseIterable & RawRepresentable>(_: E.Type) -> [String]
    where E.RawValue == String {
        E.allCases.map(\.rawValue)
    }

    @Test("pantry enums")
    func pantryEnums() {
        #expect(raw(StockLevel.self) == ["plenty", "low", "out"])
        #expect(
            raw(IngredientCategory.self) == [
                "sabzi", "fruit", "dairy", "grains", "dal", "masala", "oilGhee", "packaged",
                "other",
            ])
        #expect(raw(IngredientRole.self) == ["core", "flavor", "optional", "staple"])
        #expect(raw(BuyFrom.self) == ["sabziwala", "kirana", "dairy", "other"])
    }

    @Test("tag enums")
    func tagEnums() {
        #expect(
            raw(Region.self) == [
                "north", "south", "east", "west", "gujarati", "punjabi", "indoChinese",
                "continental", "street",
            ])
        #expect(
            raw(DishType.self) == [
                "dal", "curry", "drySabzi", "rice", "bread", "breakfast", "snack", "sweet",
                "onePot",
            ])
        #expect(raw(Flavour.self) == ["spicy", "tangy", "sweet", "savoury", "mild"])
        #expect(raw(Heaviness.self) == ["light", "medium", "heavy"])
        #expect(
            raw(Protein.self) == [
                "paneer", "dalLegume", "egg", "chicken", "mutton", "fish", "vegOnly",
            ])
        #expect(
            raw(TagDimension.self) == ["region", "dishType", "flavour", "heaviness", "protein"])
    }

    @Test("recipe, log and event enums")
    func otherEnums() {
        #expect(raw(MealType.self) == ["breakfast", "lunch", "dinner", "snack"])
        #expect(raw(DishBase.self) == ["rice", "roti", "bread", "none"])
        #expect(raw(RecipeSource.self) == ["seed", "user"])
        #expect(raw(SwipeMode.self) == ["kitchen", "craving"])
        #expect(raw(SwipeAction.self) == ["right", "left", "neverShow", "undo"])
        #expect(raw(ShoppingReason.self) == ["out", "low", "recipe", "manual"])
    }

    @Test("human labels are frozen to the Dart wording")
    func labels() {
        #expect(
            Region.allCases.map(\.label) == [
                "North Indian", "South Indian", "East Indian", "West Indian", "Gujarati",
                "Punjabi", "Indo-Chinese", "Continental", "street food",
            ])
        #expect(
            DishType.allCases.map(\.label) == [
                "dal", "curry", "dry sabzi", "rice", "bread", "breakfast", "snacks", "sweets",
                "one-pot meals",
            ])
        #expect(Flavour.allCases.map(\.label) == ["spicy", "tangy", "sweet", "savoury", "mild"])
        #expect(
            Heaviness.allCases.map(\.label) == [
                "light meals", "medium-weight meals", "hearty meals",
            ])
        #expect(
            Protein.allCases.map(\.label) == [
                "paneer", "dal and legumes", "egg", "chicken", "mutton", "fish", "veg",
            ])
    }

    @Test("enums encode as their raw string")
    func codable() throws {
        let data = try JSONEncoder().encode([IngredientCategory.oilGhee])
        #expect(String(decoding: data, as: UTF8.self) == "[\"oilGhee\"]")
        let decoded = try JSONDecoder().decode([Protein].self, from: Data("[\"dalLegume\"]".utf8))
        #expect(decoded == [.dalLegume])
    }
}
