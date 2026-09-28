import Foundation

/// Whether first-run onboarding still needs to be shown.
///
/// Completion lives in `UserDefaults` (read through `@AppStorage`), not in SwiftData. It is
/// per-install UI flow state, not household data: it is readable synchronously before the
/// store opens (no flash of the wrong screen), needs no schema change or migration, and
/// correctly stays out of JSON backups. Alternatives considered: a SwiftData flag (a schema
/// change for a UI concern, and it would travel in backups), or deriving it from "the pantry
/// is empty" (would re-show setup to anyone who skipped it).
enum OnboardingGate {
    /// The `UserDefaults` key that records onboarding as completed or skipped.
    static let completedKey = "onboardingCompleted"

    /// Launch argument (`-skipOnboarding YES`) that treats onboarding as done without
    /// persisting anything; used by UI tests that exercise other screens.
    static let skipArgumentKey = "skipOnboarding"

    /// Launch argument (`-resetOnboarding YES`) that clears the completed flag at launch, so
    /// a UI test sees the first-run flow even on a reused simulator.
    static let resetArgumentKey = "resetOnboarding"

    /// Whether the current launch asked to bypass onboarding.
    ///
    /// - Parameter defaults: Where launch arguments are visible (the argument domain).
    /// - Returns: `true` when launched with `-skipOnboarding YES`.
    static func isSkippedForThisLaunch(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: skipArgumentKey)
    }

    /// Applies `-resetOnboarding YES` (and `-uiTestFreshStore YES`, whose empty store must
    /// not inherit a finished onboarding); call once at app start.
    ///
    /// - Parameter defaults: The defaults holding the completed flag.
    static func applyLaunchArguments(_ defaults: UserDefaults = .standard) {
        if defaults.bool(forKey: resetArgumentKey)
            || defaults.bool(forKey: AppBootstrap.freshStoreArgumentKey)
        {
            defaults.removeObject(forKey: completedKey)
        }
    }

    /// Shows onboarding again: the root view observes the flag and switches immediately.
    /// This is the hook for a "Re-run setup" action in Settings.
    ///
    /// - Parameter defaults: The defaults holding the completed flag.
    static func requestRerun(_ defaults: UserDefaults = .standard) {
        defaults.set(false, forKey: completedKey)
    }
}
