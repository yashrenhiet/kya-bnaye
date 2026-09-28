import Foundation
import KyaCore
import Testing

private typealias F = CoreFixtures
private typealias T = TasteFixtures

private func withAffinity(_ value: Double) -> TasteProfile {
    TasteProfile(
        affinity: [T.north: value], evidence: [T.north: abs(value)], config: ScoringConfig())
}

/// Port of `taste_profile_test.dart`: normalisation, the asymmetry scenario and
/// `tasteScoreFor`.
@Suite("TasteProfile.normalised and tasteScore")
struct TasteProfileScoreTests {
    private let config = ScoringConfig()

    // MARK: normalised = tanh(affinity / 3)

    @Test(
        "affinity normalises to tanh(affinity / 3)",
        arguments: [
            (0, 0), (1, T.tanhOneThird), (1.5, T.tanhHalf), (3, T.tanhOne), (-3, -T.tanhOne),
            (-1, -T.tanhOneThird),
        ] as [(Double, Double)])
    func normalise(raw: Double, expected: Double) {
        #expect(F.near(withAffinity(raw).normalised(T.north), expected))
    }

    @Test("stays strictly inside (-1, 1) for moderate magnitudes")
    func moderate() {
        #expect(withAffinity(30).normalised(T.north) < 1)
        #expect(F.near(withAffinity(30).normalised(T.north), 1, eps: 1e-8))
        #expect(withAffinity(-30).normalised(T.north) > -1)
    }

    @Test("saturates to 1 instead of NaN for very large affinity")
    func saturatesPositive() {
        #expect(F.near(withAffinity(1200).normalised(T.north), 1))
        #expect(F.near(withAffinity(1_000_000).normalised(T.north), 1))
    }

    @Test("saturates to -1 for very large negative affinity")
    func saturatesNegative() {
        #expect(F.near(withAffinity(-1_000_000).normalised(T.north), -1))
    }

    @Test("unknown tag reads as neutral 0")
    func unknownTag() {
        let profile = withAffinity(3)
        #expect(profile.normalised(T.south) == 0)
        #expect(profile.evidence(for: T.south) == 0)
    }

    @Test("divisor comes from the config")
    func divisorFromConfig() {
        let profile = TasteProfile(
            affinity: [T.north: 1], evidence: [T.north: 1],
            config: ScoringConfig(tasteNormaliseDivisor: 1))
        #expect(F.near(profile.normalised(T.north), T.tanhOne))
    }

    @Test("folded profile normalises a single right swipe to tanh(1/3)")
    func foldedNormalised() {
        let profile = T.fold(events: [F.swipe("e", T.paneerCurry.id, .right, F.refNow)])
        #expect(F.near(profile.normalised(T.spicy), T.tanhOneThird))
    }

    // MARK: RECOMMENDER.md 9 asymmetry scenario

    @Test("5 left swipes do not push paneer below neutral after 3 cooks")
    func asymmetry() {
        let id = T.paneerCurry.id
        let profile = T.fold(
            events: (0..<5).map { F.swipe("l\($0)", id, .left, F.ago(days: Double($0 * 3))) },
            meals: (0..<3).map { F.cooked("m\($0)", id, F.ago(days: Double(2 + $0 * 5))) })
        #expect(profile.normalised(T.paneer) > 0)
    }

    // MARK: tasteScore weighted mean

    @Test("tag-dimension weights sum to 1")
    func weightsSumToOne() {
        let sum =
            config.taggedRegionWeight + config.taggedDishTypeWeight + config.taggedFlavourWeight
            + config.taggedHeavinessWeight + config.taggedProteinWeight
        #expect(F.near(sum, 1))
    }

    @Test("empty profile scores 0")
    func emptyProfileScore() {
        #expect(T.fold().tasteScore(for: F.defaultTags, config: config) == 0)
    }

    @Test("uniform affinity across all tags returns that normalised value")
    func uniformAffinity() {
        let profile = T.fold(events: [F.swipe("e", T.paneerCurry.id, .right, F.refNow)])
        #expect(F.near(profile.tasteScore(for: F.defaultTags, config: config), T.tanhOneThird))
    }

    @Test("each dimension is weighted per RECOMMENDER.md 4")
    func dimensionWeights() {
        let profile = TasteProfile(
            affinity: [
                T.north: 3,  // tanh(1)
                TagKey.dishType("curry"): -3,  // -tanh(1)
                TagKey.flavour("tangy"): 3,  // tanh(1)
                TagKey.flavour("mild"): 0,  // 0 -> flavour mean tanh(1) / 2
                TagKey.heaviness("light"): 1.5,  // tanh(0.5)
                TagKey.protein("egg"): 1,  // tanh(1/3)
            ],
            evidence: [:], config: config)
        let tags = DishTags(
            region: .north, dishType: .curry, flavours: [.tangy, .mild], heaviness: .light,
            protein: .egg)
        var expected = 0.25 * T.tanhOne
        expected += 0.25 * -T.tanhOne
        expected += 0.25 * (T.tanhOne / 2)
        expected += 0.10 * T.tanhHalf
        expected += 0.15 * T.tanhOneThird
        #expect(F.near(profile.tasteScore(for: tags, config: config), expected))
    }

    @Test("only the recipe's own tags are consulted")
    func ownTagsOnly() {
        let profile = T.fold(events: [F.swipe("e", T.idli.id, .neverShow, F.refNow)])
        #expect(profile.tasteScore(for: F.defaultTags, config: config) == 0)
        #expect(F.near(profile.tasteScore(for: F.otherTags, config: config), -T.tanhOne))
    }

    @Test("a dish with no flavour tags treats flavour as neutral")
    func noFlavours() {
        let profile = T.fold(events: [F.swipe("e", T.paneerCurry.id, .right, F.refNow)])
        let noFlavour = DishTags(
            region: .north, dishType: .curry, flavours: [], heaviness: .heavy, protein: .paneer)
        #expect(F.near(profile.tasteScore(for: noFlavour, config: config), 0.75 * T.tanhOneThird))
    }

    @Test("custom dimension weights are honoured")
    func customDimensionWeights() {
        let custom = ScoringConfig(
            taggedRegionWeight: 1, taggedDishTypeWeight: 0, taggedFlavourWeight: 0,
            taggedHeavinessWeight: 0, taggedProteinWeight: 0)
        let profile = TasteProfile(
            affinity: [T.north: 3, T.paneer: -3], evidence: [:], config: custom)
        #expect(F.near(profile.tasteScore(for: F.defaultTags, config: custom), T.tanhOne))
    }
}
