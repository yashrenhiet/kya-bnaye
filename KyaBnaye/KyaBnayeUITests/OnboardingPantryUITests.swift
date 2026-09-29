import XCTest

/// First run: onboarding, then the Pantry shows what was ticked and tap cycles the level.
final class OnboardingPantryUITests: XCTestCase {
    private let timeout: TimeInterval = 10

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCompletingOnboardingFillsPantryAndTapCyclesLevel() {
        let app = launchFresh()

        app.buttons["onboarding.start"].tap()
        let next = app.buttons["onboarding.next"]
        XCTAssertTrue(next.waitForExistence(timeout: timeout))
        next.tap()

        let tomato = app.buttons["onboarding.item.tomato"]
        XCTAssertTrue(tomato.waitForExistence(timeout: timeout))
        tomato.tap()
        XCTAssertEqual(tomato.value as? String, "Ticked")
        next.tap()

        for dish in ["aloo_paratha", "poha", "masala_dosa", "idli_sambar", "upma"] {
            let tile = app.buttons["onboarding.dish.\(dish)"]
            XCTAssertTrue(tile.waitForExistence(timeout: timeout), "missing dish \(dish)")
            tile.tap()
        }
        next.tap()

        let finish = app.buttons["onboarding.finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: timeout))
        finish.tap()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: timeout))
        tabBar.buttons["Pantry"].tap()

        let row = app.buttons["pantry.row.tomato"]
        XCTAssertTrue(scrollTo(row, in: app), "tomato is not in the pantry")
        XCTAssertTrue(value(of: row).hasPrefix("Plenty"), "got \(value(of: row))")
        row.tap()
        let becameLow = NSPredicate(format: "value BEGINSWITH %@", "Low")
        wait(for: [expectation(for: becameLow, evaluatedWith: row)], timeout: timeout)
    }

    @MainActor
    func testSkippingOnboardingOpensTheTabs() {
        let app = launchFresh()

        app.buttons["onboarding.skip"].tap()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: timeout))
        tabBar.buttons["Pantry"].tap()
        XCTAssertTrue(app.navigationBars["Pantry"].waitForExistence(timeout: timeout))
    }

    /// Launches as a fresh install: an empty store and the onboarding flag cleared.
    @MainActor
    private func launchFresh() -> XCUIApplication {
        let app = XCUIApplication.launchFresh(skipOnboarding: false)
        XCTAssertTrue(app.buttons["onboarding.start"].waitForExistence(timeout: timeout))
        return app
    }

    @MainActor
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        // 10, not 6: a shorter screen (e.g. iPhone SE) shows fewer rows per swipe, so a
        // count tuned for a tall device can run out before reaching a row near the bottom.
        for _ in 0..<10 {
            if element.waitForExistence(timeout: 2) && element.isHittable { return true }
            app.swipeUp()
        }
        return element.exists && element.isHittable
    }

    @MainActor
    private func value(of element: XCUIElement) -> String {
        element.value as? String ?? ""
    }
}
