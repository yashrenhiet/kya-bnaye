import XCTest

/// Home's swipe deck end to end on the real store: a Kitchen card → Want this → pick sheet
/// → Add missing → Keep swiping → Today's picks → Undo → Craving shows a card.
final class HomeDeckUITests: XCTestCase {
    private let timeout: TimeInterval = 10

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testWantThisPickAddMissingUndoAndSwitchToCraving() {
        let app = XCUIApplication.launchFresh()
        stockPotato(in: app)
        app.tabBars.firstMatch.buttons["Home"].tap()

        // Lunch always has a potato dish one or two ingredients short in the seed.
        let mealMenu = app.buttons["home.meal"]
        XCTAssertTrue(mealMenu.waitForExistence(timeout: timeout))
        mealMenu.tap()
        app.buttons["Lunch"].tap()

        let card = app.otherElements["deck.card"]
        XCTAssertTrue(card.waitForExistence(timeout: timeout), "Home should show a Kitchen card")
        let dish = card.label
        XCTAssertFalse(dish.isEmpty)

        app.buttons["deck.want"].tap()
        let addMissing = app.buttons["pick.addMissing"]
        XCTAssertTrue(addMissing.waitForExistence(timeout: timeout), "pick sheet should open")
        let picked = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", dish)).firstMatch
        XCTAssertTrue(picked.exists, "pick sheet should name \(dish)")
        if addMissing.isEnabled {
            addMissing.tap()
            XCTAssertTrue(
                app.descendants(matching: .any)["pick.added"].waitForExistence(timeout: timeout))
        }
        app.buttons["pick.keepSwiping"].tap()
        XCTAssertTrue(addMissing.waitForNonExistence(timeout: timeout))

        let pickName = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'picks.name.' AND label == %@", dish)
        ).firstMatch
        // A vertical drag that starts on the card scrolls Home rather than being swallowed.
        let header = app.staticTexts["picks.header"]
        let before = header.frame.minY
        card.swipeUp()
        XCTAssertLessThan(header.frame.minY, before, "dragging up on the card should scroll")
        XCTAssertTrue(scrollTo(pickName, in: app), "Today's picks should show \(dish)")

        let undo = app.buttons["deck.undo"]
        XCTAssertTrue(scrollTo(undo, in: app))
        undo.tap()
        XCTAssertTrue(pickName.waitForNonExistence(timeout: timeout), "undo should remove the pick")
        let restored = app.otherElements.matching(
            NSPredicate(format: "identifier == 'deck.card' AND label == %@", dish)
        ).firstMatch
        XCTAssertTrue(restored.waitForExistence(timeout: timeout), "undo should restore the card")

        app.swipeDown()
        let craving = app.segmentedControls["home.mode"].buttons["Craving"]
        XCTAssertTrue(craving.waitForExistence(timeout: timeout))
        craving.tap()
        XCTAssertTrue(craving.isSelected)
        XCTAssertTrue(card.waitForExistence(timeout: timeout), "Craving should show a card")

        // The gesture itself: a horizontal swipe on the card takes it off the deck.
        let first = card.label
        card.swipeLeft()
        let next = app.otherElements.matching(
            NSPredicate(format: "identifier == 'deck.card' AND label != %@", first)
        ).firstMatch
        XCTAssertTrue(next.waitForExistence(timeout: timeout), "swiping left should skip \(first)")
    }

    /// Marks Potato as Plenty from the Pantry tab (idempotent on a reused simulator).
    @MainActor
    private func stockPotato(in app: XCUIApplication) {
        app.tabBars.firstMatch.buttons["Pantry"].tap()
        XCTAssertTrue(app.navigationBars["Pantry"].waitForExistence(timeout: timeout))
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: timeout))
        search.tap()
        search.typeText("aloo")
        let suggestion = app.buttons["pantry.suggestion.potato"]
        if suggestion.waitForExistence(timeout: 3) { suggestion.tap() }
        let row = app.buttons["pantry.row.potato"]
        XCTAssertTrue(row.waitForExistence(timeout: timeout), "potato should be in the pantry")
        if (row.value as? String ?? "").hasPrefix("Out") { row.tap() }  // Out cycles to Plenty
        let close = app.buttons["Close"].firstMatch
        if close.exists { close.tap() }
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: timeout))
    }

    @MainActor
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        // 10, not 5: a shorter screen (e.g. iPhone SE) shows fewer rows per swipe, so a
        // count tuned for a tall device can run out before reaching a row near the bottom.
        for _ in 0..<10 {
            if element.waitForExistence(timeout: 2) && element.isHittable { return true }
            app.swipeUp()
        }
        return element.exists && element.isHittable
    }
}
