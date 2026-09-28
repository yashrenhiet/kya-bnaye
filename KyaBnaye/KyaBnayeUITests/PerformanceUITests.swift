import XCTest

/// Cold launch and deck performance, for checking on the smallest, oldest supported iPhone.
///
/// Opt-in: skipped unless the runner has `KYA_PERF` set, so it never slows the gate, e.g.
/// `TEST_RUNNER_KYA_PERF=1 xcodebuild test -only-testing:KyaBnayeUITests/PerformanceUITests`.
/// Every launch is a fresh install (in-memory store seeded from the bundle), the slowest
/// start the app has.
final class PerformanceUITests: XCTestCase {
    private let timeout: TimeInterval = 20

    override func setUpWithError() throws {
        let flag = ProcessInfo.processInfo.environment["KYA_PERF"] ?? ""
        try XCTSkipIf(flag.isEmpty, "set TEST_RUNNER_KYA_PERF=1 to measure performance")
        continueAfterFailure = false
    }

    /// Process launch until the first frame responds (`XCTApplicationLaunchMetric`).
    @MainActor
    func testColdLaunch() {
        measure(metrics: [XCTApplicationLaunchMetric(waitUntilResponsive: true)]) {
            freshApp().launch()
        }
    }

    /// Wall-clock time from the first responsive frame until Home's deck has settled (seed,
    /// load and first deck build); add ``testColdLaunch`` for the whole cold start. A fresh
    /// install has an empty pantry, so Kitchen settles on its "add to pantry" state.
    @MainActor
    func testFirstFrameToReadyDeck() {
        let options = XCTMeasureOptions()
        options.invocationOptions = [.manuallyStart, .manuallyStop]
        measure(metrics: [XCTClockMetric()], options: options) {
            let app = freshApp()
            app.launch()
            startMeasuring()
            XCTAssertTrue(app.buttons["deck.addToPantry"].waitForExistence(timeout: timeout))
            stopMeasuring()
            app.terminate()
        }
    }

    /// Switching to Craving ranks the whole recipe book off the main actor; measures until
    /// the first card shows, then five card swipes (wall clock, UI-test driving included).
    @MainActor
    func testCravingDeckBuildAndSwipes() {
        let options = XCTMeasureOptions()
        options.invocationOptions = [.manuallyStart, .manuallyStop]
        measure(metrics: [XCTClockMetric()], options: options) {
            let app = freshApp()
            app.launch()
            let craving = app.segmentedControls["home.mode"].buttons["Craving"]
            XCTAssertTrue(craving.waitForExistence(timeout: timeout))
            startMeasuring()
            craving.tap()
            let card = app.otherElements["deck.card"]
            XCTAssertTrue(card.waitForExistence(timeout: timeout))
            for _ in 0..<5 {
                let shown = card.label
                card.swipeLeft()
                let next = app.otherElements.matching(
                    NSPredicate(format: "identifier == 'deck.card' AND label != %@", shown)
                ).firstMatch
                XCTAssertTrue(next.waitForExistence(timeout: timeout))
            }
            stopMeasuring()
            app.terminate()
        }
    }

    @MainActor
    private func freshApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestFreshStore", "YES", "-skipOnboarding", "YES"]
        return app
    }
}
