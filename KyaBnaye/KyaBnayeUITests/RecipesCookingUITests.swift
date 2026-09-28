import XCTest

/// Recipe book → detail → Favourite → I made this → "Used up anything?" → History, end to
/// end on the real store.
final class RecipesCookingUITests: XCTestCase {
    private let timeout: TimeInterval = 10

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testFavouriteCookConfirmUsedUpAndSeeItInHistory() {
        let app = XCUIApplication.launchFresh()
        stockPotato(in: app)

        openRecipe(named: "Aloo Paratha", id: "aloo_paratha", in: app)

        let favourite = app.buttons["recipe.favourite"]
        XCTAssertTrue(favourite.waitForExistence(timeout: timeout))
        let wasOn = favourite.value as? String == "On"
        favourite.tap()
        let flipped = NSPredicate(format: "value == %@", wasOn ? "Off" : "On")
        wait(for: [expectation(for: flipped, evaluatedWith: favourite)], timeout: timeout)

        app.buttons["cook.madeThis"].tap()
        let low = app.buttons["usedUp.potato.low"]
        XCTAssertTrue(low.waitForExistence(timeout: timeout))
        low.tap()
        XCTAssertTrue(low.isSelected)
        app.buttons["usedUp.confirm"].tap()
        XCTAssertTrue(low.waitForNonExistence(timeout: timeout))
        let madeToday = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == 'Last made today'")).firstMatch
        XCTAssertTrue(
            madeToday.waitForExistence(timeout: timeout), "detail should show it was made today")

        app.tabBars.firstMatch.buttons["Home"].tap()
        let homeBar = app.navigationBars["Kya bnaye?"]
        XCTAssertTrue(homeBar.waitForExistence(timeout: timeout))
        homeBar.buttons["History"].tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: timeout))
        let entry = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'Aloo Paratha'")).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: timeout))
    }

    @MainActor
    func testFiltersNarrowTheListAndCanBeCleared() {
        let app = XCUIApplication.launchFresh()
        app.tabBars.firstMatch.buttons["Recipes"].tap()
        XCTAssertTrue(app.navigationBars["Recipes"].waitForExistence(timeout: timeout))

        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: timeout))
        search.tap()
        search.typeText("zzzz no such dish")
        XCTAssertTrue(app.staticTexts["No dishes match"].waitForExistence(timeout: timeout))
        app.buttons["Clear search and filters"].tap()
        XCTAssertTrue(app.buttons["recipes.row.aloo_paratha"].waitForExistence(timeout: timeout))
    }

    /// Marks Potato as Plenty from the Pantry tab, so it is a used-up candidate.
    @MainActor
    private func stockPotato(in app: XCUIApplication) {
        app.tabBars.firstMatch.buttons["Pantry"].tap()
        XCTAssertTrue(app.navigationBars["Pantry"].waitForExistence(timeout: timeout))
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: timeout))
        search.tap()
        search.typeText("aloo")
        let potato = app.buttons["pantry.suggestion.potato"]
        XCTAssertTrue(potato.waitForExistence(timeout: timeout))
        potato.tap()
        let row = app.buttons["pantry.row.potato"]
        XCTAssertTrue(row.waitForExistence(timeout: timeout), "potato should be stocked")
        XCTAssertEqual(row.value as? String, "Plenty")
        // Close the search so the keyboard no longer covers the tab bar.
        let close = app.buttons["Close"].firstMatch
        if close.exists { close.tap() }
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: timeout))
    }

    @MainActor
    private func openRecipe(named name: String, id: String, in app: XCUIApplication) {
        app.tabBars.firstMatch.buttons["Recipes"].tap()
        XCTAssertTrue(app.navigationBars["Recipes"].waitForExistence(timeout: timeout))
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: timeout))
        search.tap()
        search.typeText(name)
        let row = app.buttons["recipes.row.\(id)"]
        XCTAssertTrue(row.waitForExistence(timeout: timeout))
        row.tap()
    }
}
