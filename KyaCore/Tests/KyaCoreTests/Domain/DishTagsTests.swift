import KyaCore
import Testing

@Suite("DishTags")
struct DishTagsTests {
    private let chole = DishTags(
        region: .punjabi,
        dishType: .curry,
        flavours: [.spicy, .tangy],
        heaviness: .heavy,
        protein: .dalLegume
    )

    // MARK: allKeys

    @Test("emits one key per scalar dimension plus one per flavour")
    func oneKeyPerDimension() {
        #expect(
            chole.allKeys.sorted()
                == [
                    TagKey.region("punjabi"),
                    TagKey.dishType("curry"),
                    TagKey.flavour("spicy"),
                    TagKey.flavour("tangy"),
                    TagKey.heaviness("heavy"),
                    TagKey.protein("dalLegume"),
                ].sorted())
    }

    @Test("orders keys region, dishType, flavours by declaration, heaviness, protein")
    func deterministicOrder() {
        let reversedFlavours = DishTags(
            region: .punjabi,
            dishType: .curry,
            flavours: [.mild, .savoury, .tangy, .spicy],
            heaviness: .heavy,
            protein: .dalLegume
        )
        #expect(
            reversedFlavours.allKeys.map(\.description) == [
                "region:punjabi", "dishType:curry", "flavour:spicy", "flavour:tangy",
                "flavour:savoury", "flavour:mild", "heaviness:heavy", "protein:dalLegume",
            ])
    }

    @Test("covers every TagDimension exactly once when one flavour")
    func everyDimensionOnce() {
        let idli = DishTags(
            region: .south,
            dishType: .breakfast,
            flavours: [.mild],
            heaviness: .light,
            protein: .vegOnly
        )

        #expect(idli.allKeys.map(\.dimension).sorted() == TagDimension.allCases.sorted())
    }

    @Test("omits the flavour dimension entirely when no flavours")
    func noFlavours() {
        let plain = DishTags(
            region: .east,
            dishType: .rice,
            flavours: [],
            heaviness: .light,
            protein: .vegOnly
        )

        let keys = plain.allKeys

        #expect(keys.count == 4)
        #expect(keys.filter { $0.dimension == .flavour }.isEmpty)
    }

    @Test("uses enum raw values verbatim, including camelCase values")
    func camelCaseRawValues() {
        let momo = DishTags(
            region: .indoChinese,
            dishType: .drySabzi,
            flavours: [.savoury],
            heaviness: .medium,
            protein: .vegOnly
        )

        #expect(momo.allKeys.contains(TagKey.region("indoChinese")))
        #expect(momo.allKeys.contains(TagKey.dishType("drySabzi")))
    }

    @Test("never produces duplicate keys")
    func noDuplicates() {
        let everything = DishTags(
            region: .street,
            dishType: .snack,
            flavours: Set(Flavour.allCases),
            heaviness: .medium,
            protein: .paneer
        )

        let keys = everything.allKeys

        #expect(Set(keys).count == keys.count)
        #expect(keys.count == 4 + Flavour.allCases.count)
    }

    @Test("\"sweet\" flavour and \"sweet\" dishType are distinct keys")
    func sweetIsTwoKeys() {
        let kheer = DishTags(
            region: .north,
            dishType: .sweet,
            flavours: [.sweet],
            heaviness: .medium,
            protein: .vegOnly
        )

        let sweetKeys = kheer.allKeys.filter { $0.value == "sweet" }

        #expect(sweetKeys.count == 2)
        #expect(Set(sweetKeys).count == 2)
    }

    // MARK: equality

    @Test("equality ignores flavour set construction order")
    func equalityIgnoresOrder() {
        let reordered = DishTags(
            region: .punjabi,
            dishType: .curry,
            flavours: [.tangy, .spicy],
            heaviness: .heavy,
            protein: .dalLegume
        )

        #expect(reordered == chole)
        #expect(reordered.hashValue == chole.hashValue)
    }

    @Test("a flavour subset or superset is not equal")
    func subsetSuperset() {
        let subset = DishTags(
            region: .punjabi, dishType: .curry, flavours: [.spicy], heaviness: .heavy,
            protein: .dalLegume)
        let superset = DishTags(
            region: .punjabi, dishType: .curry, flavours: [.spicy, .tangy, .savoury],
            heaviness: .heavy, protein: .dalLegume)

        #expect(subset != chole)
        #expect(superset != chole)
    }

    @Test("differs when any scalar dimension differs")
    func scalarDimensionsMatter() {
        func vary(
            region: Region = .punjabi,
            dishType: DishType = .curry,
            heaviness: Heaviness = .heavy,
            protein: Protein = .dalLegume
        ) -> DishTags {
            DishTags(
                region: region, dishType: dishType, flavours: [.spicy, .tangy],
                heaviness: heaviness, protein: protein)
        }

        #expect(vary() == chole)
        #expect(vary(region: .north) != chole)
        #expect(vary(dishType: .dal) != chole)
        #expect(vary(heaviness: .light) != chole)
        #expect(vary(protein: .paneer) != chole)
    }
}
