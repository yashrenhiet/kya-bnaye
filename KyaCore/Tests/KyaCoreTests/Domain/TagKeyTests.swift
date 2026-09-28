import Foundation
import KyaCore
import Testing

@Suite("TagKey")
struct TagKeyTests {
    @Test("each factory pairs the value with its own dimension")
    func factories() {
        #expect(TagKey.region("south").dimension == .region)
        #expect(TagKey.dishType("dal").dimension == .dishType)
        #expect(TagKey.flavour("spicy").dimension == .flavour)
        #expect(TagKey.heaviness("light").dimension == .heaviness)
        #expect(TagKey.protein("egg").dimension == .protein)
        #expect(TagKey.region("south").value == "south")
    }

    @Test("TagValue.tagKey matches the string factories")
    func tagValueKeys() {
        #expect(Region.indoChinese.tagKey == TagKey.region("indoChinese"))
        #expect(DishType.onePot.tagKey == TagKey.dishType("onePot"))
        #expect(Flavour.sweet.tagKey == TagKey.flavour("sweet"))
        #expect(Heaviness.heavy.tagKey == TagKey.heaviness("heavy"))
        #expect(Protein.vegOnly.tagKey == TagKey.protein("vegOnly"))
    }

    @Test("same dimension and value are equal with equal hashes")
    func equality() {
        let a = TagKey.flavour("spicy")
        let b = TagKey.flavour("spicy")

        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test("the same value in different dimensions is not equal")
    func dimensionMatters() {
        #expect(TagKey.flavour("sweet") != TagKey.dishType("sweet"))
        #expect(TagKey.dishType("rice") != TagKey.region("rice"))
    }

    @Test("values are compared exactly (case-sensitive)")
    func caseSensitive() {
        #expect(TagKey.region("South") != TagKey.region("south"))
    }

    @Test("works as a dictionary key across separately built instances")
    func dictionaryKey() {
        let affinity: [TagKey: Double] = [TagKey.protein("paneer"): 0.8]

        #expect(affinity[TagKey.protein("paneer")] == 0.8)
        #expect(affinity[TagKey.protein("egg")] == nil)
    }

    @Test("description renders as dimension:value")
    func description() {
        #expect(TagKey.heaviness("heavy").description == "heaviness:heavy")
        #expect(TagKey.dishType("onePot").description == "dishType:onePot")
    }

    @Test("orders by dimension declaration order, then value")
    func ordering() {
        let keys = [
            TagKey.protein("egg"), TagKey.flavour("tangy"), TagKey.region("south"),
            TagKey.flavour("mild"), TagKey.heaviness("light"), TagKey.dishType("dal"),
        ]
        #expect(
            keys.sorted().map(\.description) == [
                "region:south", "dishType:dal", "flavour:mild", "flavour:tangy",
                "heaviness:light", "protein:egg",
            ])
        #expect(TagDimension.allCases.sorted() == TagDimension.allCases)
    }

    // MARK: label

    @Test("maps every enum value of every dimension to its human label")
    func labelsForEveryValue() {
        for region in Region.allCases {
            #expect(TagKey.region(region.rawValue).label == region.label)
        }
        for dishType in DishType.allCases {
            #expect(TagKey.dishType(dishType.rawValue).label == dishType.label)
        }
        for flavour in Flavour.allCases {
            #expect(TagKey.flavour(flavour.rawValue).label == flavour.label)
        }
        for heaviness in Heaviness.allCases {
            #expect(TagKey.heaviness(heaviness.rawValue).label == heaviness.label)
        }
        for protein in Protein.allCases {
            #expect(TagKey.protein(protein.rawValue).label == protein.label)
        }
    }

    @Test("uses spec wording, never a camelCase enum name")
    func specWording() {
        #expect(TagKey.region("indoChinese").label == "Indo-Chinese")
        #expect(TagKey.region("south").label == "South Indian")
        #expect(TagKey.region("gujarati").label == "Gujarati")
        #expect(TagKey.dishType("drySabzi").label == "dry sabzi")
    }

    @Test("every label is non-empty and has no camelCase hump")
    func labelsAreHuman() throws {
        let labelled: [[any TagLabelled]] = [
            Region.allCases, DishType.allCases, Flavour.allCases, Heaviness.allCases,
            Protein.allCases,
        ]
        let hump = try Regex("[a-z][A-Z]")
        for label in labelled.joined().map(\.label) {
            #expect(!label.trimmingCharacters(in: .whitespaces).isEmpty)
            #expect(label.firstMatch(of: hump) == nil, "\(label)")
        }
    }

    @Test("an unknown value falls back to the raw string", arguments: TagDimension.allCases)
    func unknownFallsBack(dimension: TagDimension) {
        let key: TagKey =
            switch dimension {
            case .region: .region("martian")
            case .dishType: .dishType("martian")
            case .flavour: .flavour("martian")
            case .heaviness: .heaviness("martian")
            case .protein: .protein("martian")
            }
        #expect(key.label == "martian")
    }
}
