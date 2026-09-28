import SwiftUI

@main
struct KyaBnayeApp: App {
    @State private var environment = AppEnvironment(bootstrap: .forLaunch())

    init() {
        OnboardingGate.applyLaunchArguments()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(environment)
        }
    }
}
