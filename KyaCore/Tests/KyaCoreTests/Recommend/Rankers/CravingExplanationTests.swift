import Foundation
import KyaCore
import Testing

private typealias F = RankerFixtures

private let ranker = CravingRanker()

private func score(
    _ recipeId: String,
    pantry: [PantryItem] = [],
    events: [SwipeEvent] = [],
    meals: [MealLog] = []
) -> ScoredRecipe? {
    ranker.score(
        F.recipe(recipeId),
        in: F.contextFor(now: F.weekdayDinner, pantry: pantry, events: events, meals: meals))
}

/// Port of `craving_ranker_test.dart`, group "explanations".
@Suite("CravingRanker explanations")
struct CravingExplanationTests {
    private let dinner = F.weekdayDinner

    @Test("Because you liked X. when tag overlap (Jaccard) >= 0.34")
    func becauseYouLiked() {
        // Chole vs Rajma Chawal: 5 shared of 7 distinct tags.
        let result = score(
            "chole_bhature", events: [F.right("rajma_chawal", F.daysBefore(dinner, 5))])
        #expect(result?.explanation == "Because you liked Rajma Chawal.")
    }

    @Test("a cooked dish counts as liked")
    func cookedCountsAsLiked() {
        let result = score(
            "chole_bhature", meals: [F.cooked("rajma_chawal", F.daysBefore(dinner, 20))])
        #expect(result?.explanation == "Because you liked Rajma Chawal.")
    }

    @Test("picks the liked dish with the highest overlap, not the newest")
    func highestOverlap() {
        // Aloo Matar vs Egg Curry: 4/8; vs Dal Tadka: 3/9.
        let result = score(
            "aloo_matar",
            events: [
                F.right("egg_curry", F.daysBefore(dinner, 10)),
                F.right("dal_tadka", F.daysBefore(dinner, 1)),
            ])
        #expect(result?.explanation == "Because you liked Egg Curry.")
    }

    @Test("Jaccard of exactly 1/3 is below 0.34 -> falls back to a tag")
    func oneThirdFallsBack() {
        // Poha vs Lemon Rice: savoury, light, vegOnly shared of 9 -> 0.333.
        let result = score("poha", events: [F.right("lemon_rice", F.daysBefore(dinner, 1))])
        #expect(result?.explanation == "You've been into savoury lately.")
    }

    @Test("never cites the candidate itself as the liked dish")
    func neverCitesItself() throws {
        let result = try #require(
            score("rajma_chawal", events: [F.right("rajma_chawal", F.daysBefore(dinner, 1))]))
        #expect(!result.explanation.contains("Because you liked"))
        #expect(result.explanation.hasPrefix("You've been into "))
        #expect(result.explanation.hasSuffix(" lately."))
    }

    @Test("likes older than 60 days are not cited; weak tags fall through to the pantry line")
    func oldLikes() {
        let result = score(
            "chole_bhature", events: [F.right("rajma_chawal", F.daysBefore(dinner, 61))])
        // Only salt and oil (staples) are "at home".
        #expect(result?.explanation == "You already have 2 of 7 ingredients.")
    }

    @Test("an undone right swipe is not cited")
    func undoneRightSwipe() {
        let swipe = F.right("rajma_chawal", F.daysBefore(dinner, 1))
        let undo = SwipeEvent(
            id: "undo-1", recipeId: "rajma_chawal", action: .undo, mode: .craving,
            at: F.daysBefore(dinner, 1), deckSeed: 1, undoesEventId: swipe.id)
        let result = score("chole_bhature", events: [swipe, undo])
        #expect(result?.explanation == "You already have 2 of 7 ingredients.")
    }

    @Test("no history -> You already have a of b ingredients.")
    func pantryLine() {
        // Potato + salt, oil, haldi (staples) of 7 required.
        let result = score("aloo_matar", pantry: F.haveAll(["potato"]))
        #expect(result?.explanation == "You already have 4 of 7 ingredients.")
    }

    @Test("tag lines use a human label, not the enum name")
    func humanLabel() {
        let result = score(
            "veg_hakka_noodles", events: [F.right("veg_hakka_noodles", F.daysBefore(dinner, 1))])
        #expect(result?.explanation.contains("Indo-Chinese") == true)
    }

    @Test("never returns an empty explanation")
    func neverEmpty() {
        let contexts = [
            F.contextFor(now: dinner),
            F.contextFor(
                now: dinner,
                events: [
                    F.right("masala_dosa", F.daysBefore(dinner, 1)),
                    F.right("upma", F.daysBefore(dinner, 2)),
                    F.right("lemon_rice", F.daysBefore(dinner, 3)),
                ]),
            F.contextFor(
                now: F.saturdayDinner, pantry: F.haveAll(["rice", "onion"]),
                meals: [F.cooked("dal_tadka", F.daysBefore(F.saturdayDinner, 3))]),
        ]
        for context in contexts {
            for recipe in F.recipes {
                let explanation = ranker.score(recipe, in: context)?.explanation ?? ""
                #expect(!explanation.trimmingCharacters(in: .whitespaces).isEmpty, "\(recipe)")
            }
        }
    }
}
