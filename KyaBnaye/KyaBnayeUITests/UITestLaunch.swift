import XCTest

extension XCUIApplication {
    /// Launches the app on its own empty, freshly seeded in-memory store
    /// (`-uiTestFreshStore YES`), so no UI test depends on what another left behind.
    ///
    /// - Parameters:
    ///   - skipOnboarding: Whether to bypass first-run onboarding (the default); pass
    ///     `false` to see onboarding, which a fresh store always starts with.
    ///   - extra: More launch arguments, e.g. a preferred text size.
    /// - Returns: The launched app.
    @MainActor
    static func launchFresh(skipOnboarding: Bool = true, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestFreshStore", "YES"]
        if skipOnboarding { app.launchArguments += ["-skipOnboarding", "YES"] }
        app.launchArguments += extra
        app.launch()
        return app
    }
}
