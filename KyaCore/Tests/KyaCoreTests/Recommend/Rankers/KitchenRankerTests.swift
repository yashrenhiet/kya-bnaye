import Foundation
import KyaCore
import Testing

private typealias F = RankerFixtures
private typealias K = KitchenHarness

/// Shared helpers for the `kitchen_ranker_test.dart` port.
enum KitchenHarness {
    /// Makes Aloo Matar fully cookable (staples assumed present).
    static let alooMatarPantry = ["potato", "matar", "onion", "tomato"]

    /// Makes Palak Paneer fully cookable.
    static let palakPaneerPantry = ["palak", "paneer", "onion", "ginger_garlic", "kasuri_methi"]

    /// Isolates non-taste terms: history still feeds penalties.
    static let noTaste = ScoringConfig(kitchenTasteWeight: 0)

    static let ranker = KitchenRanker()

    static func score(
        _ recipeId: String,
        pantry: [PantryItem] = [],
        events: [SwipeEvent] = [],
        meals: [MealLog] = [],
        mealType: MealType? = .dinner,
        config: ScoringConfig = ScoringConfig(),
        now: Date? = nil
    ) -> ScoredRecipe? {
        ranker.score(
            F.recipe(recipeId),
            in: F.contextFor(
                now: now ?? F.weekdayDinner, pantry: pantry, events: events, meals: meals,
                mealType: mealType, config: config))
    }

    /// Palak expiring `days` after Wednesday dinner plus the rest of its pantry.
    static func palakExpiring(in days: Int) -> [PantryItem] {
        [F.have("palak", expiresOn: F.daysAfter(F.weekdayDinner, days))]
            + F.haveAll(Array(palakPaneerPantry.dropFirst()))
    }
}

/// Port of `kitchen_ranker_test.dart`: tiers and availability rules.
@Suite("KitchenRanker: tiers and availability")
struct KitchenRankerTests {
    @Test("does not support exploration")
    func noExploration() {
        #expect(!K.ranker.supportsExploration)
    }

    // MARK: tiers

    @Test("everything at home -> Ready now, nothing missing")
    func readyNow() throws {
        let result = try #require(K.score("aloo_matar", pantry: F.haveAll(K.alooMatarPantry)))
        #expect(result.tier == .readyNow)
        #expect(result.missingIngredientIds.isEmpty)
    }

    @Test("one non-optional ingredient absent -> Missing 1")
    func missingOne() throws {
        let result = try #require(
            K.score("aloo_matar", pantry: F.haveAll(["potato", "onion", "tomato"])))
        #expect(result.tier == .missing1)
        #expect(result.missingIngredientIds == ["matar"])
    }

    @Test("two absent -> Missing 2, listed in recipe order")
    func missingTwo() throws {
        let result = try #require(K.score("aloo_matar", pantry: F.haveAll(["potato", "onion"])))
        #expect(result.tier == .missing2)
        #expect(result.missingIngredientIds == ["matar", "tomato"])
    }

    @Test("more than two missing is excluded (hard filter)")
    func tooManyMissing() {
        #expect(K.score("aloo_matar", pantry: F.haveAll(["potato"])) == nil)
    }

    @Test("empty pantry excludes every dish needing 3+ non-staples")
    func emptyPantry() {
        #expect(K.score("aloo_matar") == nil)
        #expect(K.score("dal_tadka") == nil)
        #expect(K.score("jeera_rice")?.tier == .missing1)
    }

    @Test("an ingredient expiring within 3 days -> Use it up")
    func useItUp() throws {
        let result = try #require(K.score("palak_paneer", pantry: K.palakExpiring(in: 1)))
        #expect(result.tier == .useItUp)
        #expect(result.missingIngredientIds.isEmpty)
    }

    @Test("Use it up wins over Missing 2 for the badge")
    func useItUpBeatsMissing() throws {
        let pantry =
            [F.have("palak", expiresOn: F.weekdayDinner)] + F.haveAll(["paneer", "onion"])
        let result = try #require(K.score("palak_paneer", pantry: pantry))
        #expect(result.tier == .useItUp)
        #expect(result.missingIngredientIds == ["ginger_garlic", "kasuri_methi"])
    }

    @Test("expiry exactly 3 days out still counts; 4 days does not")
    func expiryBoundary() {
        #expect(K.score("palak_paneer", pantry: K.palakExpiring(in: 3))?.tier == .useItUp)
        #expect(K.score("palak_paneer", pantry: K.palakExpiring(in: 4))?.tier == .readyNow)
    }

    @Test("an Out item with a near expiry is missing, not use it up")
    func outWithExpiry() throws {
        let palak = PantryItem(
            ingredientId: "palak", level: .out, updatedAt: F.weekdayDinner,
            expiresOn: F.weekdayDinner)
        let pantry = [palak] + F.haveAll(Array(K.palakPaneerPantry.dropFirst()))
        let result = try #require(K.score("palak_paneer", pantry: pantry))
        #expect(result.tier == .missing1)
        #expect(result.missingIngredientIds == ["palak"])
    }

    // MARK: availability rules

    @Test("optional (garnish) ingredients never count as missing")
    func garnishNeverMissing() throws {
        let result = try #require(K.score("aloo_matar", pantry: F.haveAll(K.alooMatarPantry)))
        #expect(!result.missingIngredientIds.contains("coriander"))
        #expect(result.tier == .readyNow)
    }

    @Test("an Out garnish still does not count as missing")
    func outGarnish() {
        let pantry = F.haveAll(K.alooMatarPantry) + [F.out("coriander")]
        #expect(K.score("aloo_matar", pantry: pantry)?.tier == .readyNow)
    }

    @Test("an ingredient whose catalog role is optional never counts as missing")
    func optionalRole() throws {
        let kachumber = Recipe(
            id: "kachumber", name: "Kachumber", mealTypes: [.dinner], minutes: 10, base: .none,
            ingredients: ["onion", "tomato", "coriander"].map {
                RecipeIngredient(ingredientId: $0, quantityText: "1")
            },
            steps: ["Chop and toss."], tags: F.recipe("dal_tadka").tags, source: .user)
        let context = F.contextFor(
            now: F.weekdayDinner, pantry: F.haveAll(["onion", "tomato"]), mealType: .dinner)
        let result = try #require(K.ranker.score(kachumber, in: context))
        #expect(result.missingIngredientIds.isEmpty)
        #expect(result.tier == .readyNow)
    }

    @Test("staples with no pantry row are assumed present")
    func staplesAssumed() {
        let result = K.score("aloo_matar", pantry: F.haveAll(K.alooMatarPantry))
        #expect(result?.missingIngredientIds.isEmpty == true)
    }

    @Test("a staple explicitly marked Out counts as missing")
    func stapleOut() throws {
        let pantry = F.haveAll(K.alooMatarPantry) + [F.out("oil")]
        let result = try #require(K.score("aloo_matar", pantry: pantry))
        #expect(result.tier == .missing1)
        #expect(result.missingIngredientIds == ["oil"])
    }

    @Test("a staple Out pushes a Missing 2 dish over the limit")
    func stapleOutOverLimit() {
        let pantry = F.haveAll(["potato", "onion"]) + [F.out("salt")]
        #expect(K.score("aloo_matar", pantry: pantry) == nil)
    }

    @Test("Low counts as available")
    func lowAvailable() throws {
        let pantry = K.alooMatarPantry.map { F.have($0, level: .low) }
        let result = try #require(K.score("aloo_matar", pantry: pantry))
        #expect(result.tier == .readyNow)
        #expect(result.missingIngredientIds.isEmpty)
    }

    @Test("a staple earns no rarity bonus (weight is its role weight)")
    func stapleWeight() {
        let context = F.contextFor(now: F.weekdayDinner)
        #expect(CoreFixtures.near(context.ingredientWeight("salt"), 0.25))
    }
}
