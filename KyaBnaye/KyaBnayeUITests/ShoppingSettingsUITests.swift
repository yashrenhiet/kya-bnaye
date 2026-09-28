import XCTest

/// Shopping list and Settings backup, end to end on the real store.
final class ShoppingSettingsUITests: XCTestCase {
    private let timeout: TimeInterval = 10

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAddManualItemTickAndMoveToPantry() {
        let app = XCUIApplication.launchFresh()
        app.tabBars.firstMatch.buttons["Shopping"].tap()
        XCTAssertTrue(app.navigationBars["Shopping"].waitForExistence(timeout: timeout))

        let name = "Candles \(UUID().uuidString.prefix(6))"
        let add = app.buttons["shopping.addItem"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: timeout))
        add.tap()
        let field = app.textFields["shopping.add.field"]
        XCTAssertTrue(field.waitForExistence(timeout: timeout))
        field.typeText(name)
        app.buttons["shopping.add.confirm"].tap()
        let feedback = app.staticTexts["shopping.add.feedback"]
        XCTAssertTrue(feedback.waitForExistence(timeout: timeout))
        XCTAssertEqual(feedback.label, "Added \(name).")
        app.buttons["shopping.add.done"].tap()

        let row = app.buttons["shopping.row.\(name)"]
        XCTAssertTrue(row.waitForExistence(timeout: timeout))
        XCTAssertEqual(row.value as? String, "Not bought")
        row.tap()
        let bought = expectation(for: NSPredicate(format: "value == 'Bought'"), evaluatedWith: row)
        wait(for: [bought], timeout: timeout)

        let move = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Move '")).firstMatch
        XCTAssertTrue(move.waitForExistence(timeout: timeout))
        move.tap()
        XCTAssertTrue(row.waitForNonExistence(timeout: timeout))
    }

    @MainActor
    func testSettingsExportShowsTheBackupSheet() {
        let app = XCUIApplication.launchFresh()
        let homeBar = app.navigationBars["Kya bnaye?"]
        XCTAssertTrue(homeBar.waitForExistence(timeout: timeout))
        homeBar.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: timeout))

        app.buttons["settings.export"].tap()

        XCTAssertTrue(app.staticTexts["Your backup is ready"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.buttons["Share backup"].exists)
        XCTAssertTrue(app.buttons["Save to Files"].exists)
    }
}
