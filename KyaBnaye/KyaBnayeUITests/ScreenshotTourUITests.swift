import XCTest

/// Walks every main screen and saves a screenshot of each, for reviewing layout at the
/// default text size and the largest accessibility size.
///
/// Opt-in: skipped unless the runner has `KYA_SHOTS` set to an output directory, e.g.
/// `TEST_RUNNER_KYA_SHOTS=/tmp/kya-shots xcodebuild test -only-testing:…/ScreenshotTourUITests`.
/// For dark mode, run it after `xcrun simctl ui <device> appearance dark`.
final class ScreenshotTourUITests: XCTestCase {
    private let timeout: TimeInterval = 10
    private var directory = URL(fileURLWithPath: NSTemporaryDirectory())

    override func setUpWithError() throws {
        let path = ProcessInfo.processInfo.environment["KYA_SHOTS"] ?? ""
        try XCTSkipIf(path.isEmpty, "set TEST_RUNNER_KYA_SHOTS to take screenshots")
        directory = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        continueAfterFailure = true
    }

    @MainActor
    func testTourDefault() {
        tour(prefix: "default")
    }

    @MainActor
    func testTourAccessibilitySize() {
        tour(prefix: "ax5", contentSize: "UICTContentSizeCategoryAccessibilityXXXL")
    }

    @MainActor
    private func tour(prefix: String, contentSize: String? = nil) {
        var arguments: [String] = []
        if let contentSize { arguments = ["-UIPreferredContentSizeCategoryName", contentSize] }

        let onboarding = XCUIApplication.launchFresh(skipOnboarding: false, extra: arguments)
        XCTAssertTrue(onboarding.buttons["onboarding.start"].waitForExistence(timeout: timeout))
        shoot("\(prefix)-01-onboarding")
        onboarding.buttons["onboarding.start"].tap()
        _ = onboarding.buttons["onboarding.next"].waitForExistence(timeout: timeout)
        shoot("\(prefix)-02-onboarding-staples")

        let app = XCUIApplication.launchFresh(extra: arguments)
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: timeout))
        _ = app.buttons["home.meal"].waitForExistence(timeout: timeout)
        shoot("\(prefix)-03-home")
        app.swipeUp()
        shoot("\(prefix)-04-home-scrolled")

        tabBar.buttons["Pantry"].tap()
        _ = app.navigationBars["Pantry"].waitForExistence(timeout: timeout)
        shoot("\(prefix)-05-pantry")

        tabBar.buttons["Recipes"].tap()
        let row = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'recipes.row.'")
        ).firstMatch
        _ = row.waitForExistence(timeout: timeout)
        shoot("\(prefix)-06-recipes")
        row.tap()
        _ = app.buttons["cook.madeThis"].waitForExistence(timeout: timeout)
        shoot("\(prefix)-07-recipe-detail")
        app.swipeUp()
        shoot("\(prefix)-08-recipe-detail-scrolled")

        tabBar.buttons["Shopping"].tap()
        _ = app.navigationBars["Shopping"].waitForExistence(timeout: timeout)
        shoot("\(prefix)-09-shopping")

        tabBar.buttons["Home"].tap()
        let homeBar = app.navigationBars["Kya bnaye?"]
        _ = homeBar.waitForExistence(timeout: timeout)
        homeBar.buttons["History"].tap()
        _ = app.navigationBars["History"].waitForExistence(timeout: timeout)
        shoot("\(prefix)-10-history")
        app.navigationBars["History"].buttons.firstMatch.tap()
        _ = homeBar.waitForExistence(timeout: timeout)
        homeBar.buttons["Settings"].tap()
        _ = app.navigationBars["Settings"].waitForExistence(timeout: timeout)
        shoot("\(prefix)-11-settings")
        app.swipeUp()
        shoot("\(prefix)-12-settings-scrolled")
    }

    @MainActor
    private func shoot(_ name: String) {
        let data = XCUIScreen.main.screenshot().pngRepresentation
        XCTAssertNoThrow(try data.write(to: directory.appendingPathComponent("\(name).png")))
    }
}
