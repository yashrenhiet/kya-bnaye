import XCTest

/// Runs Xcode's accessibility audit (contrast, hit regions, Dynamic Type, labels, traits,
/// clipped text) on every main screen, reporting all issues of a screen at once.
final class AccessibilityAuditUITests: XCTestCase {
    private let timeout: TimeInterval = 10

    /// Button titles in List rows that the audit reports as clipped although they render in
    /// full, checked by eye at the default and largest accessibility sizes with
    /// `ScreenshotTourUITests`. Keep this list short and re-check it when the layout changes.
    private static let verifiedUnclipped: Set<String> = ["Reset all data…", "Add what's at home"]

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    /// Polls until `element` is hittable (exists, on screen, not obstructed), not merely
    /// `exists`. Running the audit right after a push/tab transition can snapshot a frame
    /// mid-animation, which produced a one-off flaky contrast/clipping report (confirmed
    /// non-reproducing on a clean re-run) — waiting for a settled, hittable element first
    /// avoids photographing a layout that is still moving.
    @MainActor
    private func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists && element.isHittable { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return element.exists && element.isHittable
    }

    @MainActor
    func testTabScreensPassAudit() throws {
        let app = XCUIApplication.launchFresh()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: timeout))

        XCTAssertTrue(app.buttons["home.meal"].waitForExistence(timeout: timeout))
        try audit(app, screen: "Home")

        tabBar.buttons["Pantry"].tap()
        XCTAssertTrue(app.navigationBars["Pantry"].waitForExistence(timeout: timeout))
        try audit(app, screen: "Pantry")

        tabBar.buttons["Recipes"].tap()
        let row = app.buttons.matching(identifier: "recipes.row.aloo_paratha").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: timeout))
        try audit(app, screen: "Recipes")

        row.tap()
        XCTAssertTrue(app.buttons["cook.madeThis"].waitForExistence(timeout: timeout))
        try audit(app, screen: "Recipe detail")

        tabBar.buttons["Shopping"].tap()
        XCTAssertTrue(app.navigationBars["Shopping"].waitForExistence(timeout: timeout))
        try audit(app, screen: "Shopping")
    }

    @MainActor
    func testPushedScreensPassAudit() throws {
        let app = XCUIApplication.launchFresh()
        let homeBar = app.navigationBars["Kya bnaye?"]
        XCTAssertTrue(homeBar.waitForExistence(timeout: timeout))

        homeBar.buttons["History"].tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: timeout))
        XCTAssertTrue(waitUntilHittable(app.navigationBars["History"]))
        try audit(app, screen: "History")
        app.navigationBars["History"].buttons.firstMatch.tap()

        XCTAssertTrue(homeBar.waitForExistence(timeout: timeout))
        homeBar.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: timeout))
        XCTAssertTrue(waitUntilHittable(app.navigationBars["Settings"]))
        try audit(app, screen: "Settings")
    }

    @MainActor
    func testOnboardingPassesAudit() throws {
        let app = XCUIApplication.launchFresh(skipOnboarding: false)
        let next = app.buttons["onboarding.start"]
        XCTAssertTrue(next.waitForExistence(timeout: timeout))
        try audit(app, screen: "Onboarding welcome")
        next.tap()
        XCTAssertTrue(app.buttons["onboarding.next"].waitForExistence(timeout: timeout))
        XCTAssertTrue(waitUntilHittable(app.buttons["onboarding.next"]))
        try audit(app, screen: "Onboarding staples")
    }

    /// Audits what is on screen and fails once, listing every issue found.
    ///
    /// Known false positives are skipped, each covered another way:
    /// - Dynamic Type: the audit flags List headers, menu labels and chips that do scale;
    ///   `ScreenshotTourUITests` checks every screen at the largest accessibility size.
    /// - Contrast with no element, or on content under the translucent tab bar or partly off
    ///   screen: the audit samples blurred or decorative pixels (the artwork initial).
    ///   Every text colour pair is checked at 4.5:1 by `ThemeContrastTests`.
    /// - Clipping with no element (nothing to fix or locate), in the system search field's
    ///   placeholder, or on content partly off screen in a horizontal scroller.
    @MainActor
    private func audit(_ app: XCUIApplication, screen: String) throws {
        let tabBar = app.tabBars.firstMatch
        let tabBarTop = tabBar.exists ? tabBar.frame.minY : .greatestFiniteMagnitude
        let window = app.windows.firstMatch.frame
        var issues: [String] = []
        try app.performAccessibilityAudit(for: .all.subtracting(.dynamicType)) { issue in
            let isVisual = issue.auditType == .contrast || issue.auditType == .textClipped
            guard let element = issue.element else { return isVisual }
            let frame = element.frame
            if isVisual && !window.contains(frame) { return true }
            if issue.auditType == .contrast && frame.maxY > tabBarTop { return true }
            // The artwork initial ("A") is a decorative graphic, hidden from VoiceOver, with the
            // dish name always shown beside it (WCAG 1.4.3 exempts text in a picture).
            if issue.auditType == .contrast && element.label.count == 1 { return true }
            if issue.auditType == .textClipped
                && (element.elementType == .searchField
                    || Self.verifiedUnclipped.contains(element.label))
            {
                return true
            }
            issues.append(
                "\(issue.compactDescription) — \(element.elementType) '\(element.label)' "
                    + element.identifier)
            return true
        }
        XCTAssert(
            issues.isEmpty, "\(screen): \(issues.count) issue(s)\n" + issues.joined(separator: "\n")
        )
    }
}
