import XCTest

/// The M8 critical path on a fresh install, end to end on the real store: onboarding →
/// pantry → Kitchen swipe right → Craving swipe right → recipe detail "Add missing to
/// shopping list" → I made this → Shopping shows the added items → bought moves to pantry.
final class CriticalPathUITests: XCTestCase {
    private let timeout: TimeInterval = 10

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testFreshInstallToShoppingAndBackToPantry() {
        let app = XCUIApplication.launchFresh(skipOnboarding: false)
        onboard(app, fridge: ["onion", "tomato", "potato"])
        checkPantry(app, stocked: ["onion", "tomato", "potato"])

        app.tabBars.firstMatch.buttons["Home"].tap()
        chooseLunch(in: app)
        let kitchenPick = swipeRightAndKeepSwiping(in: app)
        let pickName = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'picks.name.' AND label == %@", kitchenPick)
        ).firstMatch
        XCTAssertTrue(scrollTo(pickName, in: app), "Today's picks should show \(kitchenPick)")

        scrollToTop(of: app)
        let craving = app.segmentedControls["home.mode"].buttons["Craving"]
        XCTAssertTrue(craving.waitForExistence(timeout: timeout))
        craving.tap()
        XCTAssertTrue(craving.isSelected)
        let dish = pickCravingDishWithSomethingMissing(in: app)

        app.buttons["pick.viewRecipe"].tap()
        let missingCount = addMissingFromDetail(in: app)
        cook(in: app)

        app.tabBars.firstMatch.buttons["Shopping"].tap()
        XCTAssertTrue(app.navigationBars["Shopping"].waitForExistence(timeout: timeout))
        let names = buyEverything(for: dish, expecting: missingCount, in: app)

        app.tabBars.firstMatch.buttons["Pantry"].tap()
        XCTAssertTrue(app.navigationBars["Pantry"].waitForExistence(timeout: timeout))
        for name in names {
            let row = app.buttons.matching(
                NSPredicate(format: "identifier BEGINSWITH 'pantry.row.' AND label == %@", name)
            ).firstMatch
            XCTAssertTrue(scrollTo(row, in: app), "\(name) should be in the pantry")
            XCTAssertTrue(value(of: row).hasPrefix("Plenty"), "\(name) is \(value(of: row))")
            scrollToTop(of: app)
        }
    }

    // MARK: Steps

    /// Welcome → staples (all ticked) → fridge (ticks `fridge`) → five dishes → done.
    @MainActor
    private func onboard(_ app: XCUIApplication, fridge: [String]) {
        let start = app.buttons["onboarding.start"]
        XCTAssertTrue(start.waitForExistence(timeout: timeout))
        start.tap()
        let next = app.buttons["onboarding.next"]
        XCTAssertTrue(next.waitForExistence(timeout: timeout))
        next.tap()

        for id in fridge {
            let item = app.buttons["onboarding.item.\(id)"]
            XCTAssertTrue(item.waitForExistence(timeout: timeout), "missing fridge item \(id)")
            if value(of: item) != "Ticked" { item.tap() }
            XCTAssertEqual(value(of: item), "Ticked")
        }
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
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: timeout))
    }

    /// The Pantry lists what onboarding ticked, as Plenty.
    @MainActor
    private func checkPantry(_ app: XCUIApplication, stocked ids: [String]) {
        app.tabBars.firstMatch.buttons["Pantry"].tap()
        XCTAssertTrue(app.navigationBars["Pantry"].waitForExistence(timeout: timeout))
        for id in ids {
            let row = app.buttons["pantry.row.\(id)"]
            XCTAssertTrue(scrollTo(row, in: app), "\(id) is not in the pantry")
            XCTAssertTrue(value(of: row).hasPrefix("Plenty"), "\(id) is \(value(of: row))")
            scrollToTop(of: app)
        }
    }

    /// Lunch always has potato / onion / tomato dishes in the seed.
    @MainActor
    private func chooseLunch(in app: XCUIApplication) {
        let mealMenu = app.buttons["home.meal"]
        XCTAssertTrue(mealMenu.waitForExistence(timeout: timeout))
        mealMenu.tap()
        let lunch = app.buttons["Lunch"]
        XCTAssertTrue(lunch.waitForExistence(timeout: timeout))
        lunch.tap()
    }

    /// Swipes the top card right with the gesture, checks the pick sheet names it, then
    /// closes the sheet with Keep swiping.
    ///
    /// - Returns: The dish that was picked.
    @MainActor
    @discardableResult
    private func swipeRightAndKeepSwiping(in app: XCUIApplication) -> String {
        let dish = swipeTopCardRight(in: app)
        app.buttons["pick.keepSwiping"].tap()
        XCTAssertTrue(app.buttons["pick.keepSwiping"].waitForNonExistence(timeout: timeout))
        return dish
    }

    /// Swipes Craving cards right until one has something missing, leaving its pick sheet
    /// open. Up to eight tries; a new install's Craving deck always has such a dish.
    ///
    /// - Returns: The dish whose pick sheet is open.
    @MainActor
    private func pickCravingDishWithSomethingMissing(in app: XCUIApplication) -> String {
        for _ in 0..<8 {
            let dish = swipeTopCardRight(in: app)
            if app.buttons["pick.addMissing"].isEnabled { return dish }
            app.buttons["pick.keepSwiping"].tap()
            XCTAssertTrue(app.buttons["pick.keepSwiping"].waitForNonExistence(timeout: timeout))
        }
        XCTFail("no Craving dish with missing ingredients in eight cards")
        return ""
    }

    @MainActor
    private func swipeTopCardRight(in app: XCUIApplication) -> String {
        let card = app.otherElements["deck.card"]
        XCTAssertTrue(card.waitForExistence(timeout: timeout), "Home should show a card")
        let dish = card.label
        XCTAssertFalse(dish.isEmpty)
        card.swipeRight()
        let keepSwiping = app.buttons["pick.keepSwiping"]
        XCTAssertTrue(keepSwiping.waitForExistence(timeout: timeout), "pick sheet should open")
        let named = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", dish)).firstMatch
        XCTAssertTrue(named.exists, "pick sheet should name \(dish)")
        return dish
    }

    /// On the recipe detail, taps "Add N missing to shopping list".
    ///
    /// - Returns: N.
    @MainActor
    private func addMissingFromDetail(in app: XCUIApplication) -> Int {
        let add = app.buttons["recipe.addMissing"]
        XCTAssertTrue(scrollTo(add, in: app), "detail should offer Add missing")
        let count = add.label.split(separator: " ").dropFirst().first.flatMap { Int($0) } ?? 0
        XCTAssertGreaterThan(count, 0, "unexpected label \(add.label)")
        add.tap()
        let added = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'Added '")).firstMatch
        XCTAssertTrue(added.waitForExistence(timeout: timeout), "should confirm the add")
        return count
    }

    /// I made this → answers "Used up anything?" if asked → detail shows it was made today.
    @MainActor
    private func cook(in app: XCUIApplication) {
        app.buttons["cook.madeThis"].tap()
        let skip = app.buttons["usedUp.skip"]
        if skip.waitForExistence(timeout: 3) {
            skip.tap()
            XCTAssertTrue(skip.waitForNonExistence(timeout: timeout))
        }
        let madeToday = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == 'Last made today'")).firstMatch
        XCTAssertTrue(
            madeToday.waitForExistence(timeout: timeout), "detail should show it was made today")
    }

    /// Ticks every row added for `dish`, then moves them to the pantry.
    ///
    /// - Returns: The bought item names.
    @MainActor
    private func buyEverything(
        for dish: String, expecting count: Int, in app: XCUIApplication
    ) -> [String] {
        let fromDish = NSPredicate(
            format: "identifier BEGINSWITH 'shopping.row.' AND label ENDSWITH %@", "from: \(dish)")
        let rows = app.buttons.matching(fromDish)
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: timeout), "no rows for \(dish)")
        XCTAssertEqual(rows.count, count, "Shopping should list every missing item")

        var names: [String] = []
        for index in 0..<rows.count {
            let row = rows.element(boundBy: index)
            XCTAssertTrue(scrollTo(row, in: app))
            names.append(String(row.identifier.dropFirst("shopping.row.".count)))
            row.tap()
            let bought = NSPredicate(format: "value == 'Bought'")
            wait(for: [expectation(for: bought, evaluatedWith: row)], timeout: timeout)
        }

        let move = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Move '")).firstMatch
        XCTAssertTrue(move.waitForExistence(timeout: timeout))
        move.tap()
        XCTAssertTrue(rows.firstMatch.waitForNonExistence(timeout: timeout))
        return names
    }

    // MARK: Helpers

    @MainActor
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        for _ in 0..<6 {
            if element.waitForExistence(timeout: 2) && element.isHittable { return true }
            app.swipeUp()
        }
        return element.exists && element.isHittable
    }

    @MainActor
    private func scrollToTop(of app: XCUIApplication) {
        for _ in 0..<3 { app.swipeDown() }
    }

    private func value(of element: XCUIElement) -> String {
        element.value as? String ?? ""
    }
}
