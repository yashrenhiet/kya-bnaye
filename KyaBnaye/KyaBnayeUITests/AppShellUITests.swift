import XCTest

final class AppShellUITests: XCTestCase {
    private let timeout: TimeInterval = 10

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testFourTabsExistAndPantryOpens() {
        let app = XCUIApplication.launchFresh()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: timeout))
        for title in ["Home", "Pantry", "Recipes", "Shopping"] {
            XCTAssertTrue(tabBar.buttons[title].exists, "missing tab \(title)")
        }

        tabBar.buttons["Pantry"].tap()
        XCTAssertTrue(app.navigationBars["Pantry"].waitForExistence(timeout: timeout))
    }

    @MainActor
    func testHistoryAndSettingsReachableFromHome() {
        let app = XCUIApplication.launchFresh()

        let homeBar = app.navigationBars["Kya bnaye?"]
        XCTAssertTrue(homeBar.waitForExistence(timeout: timeout))

        homeBar.buttons["History"].tap()
        let historyBar = app.navigationBars["History"]
        XCTAssertTrue(historyBar.waitForExistence(timeout: timeout))
        historyBar.buttons.firstMatch.tap()

        XCTAssertTrue(homeBar.waitForExistence(timeout: timeout))
        homeBar.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: timeout))
    }
}
