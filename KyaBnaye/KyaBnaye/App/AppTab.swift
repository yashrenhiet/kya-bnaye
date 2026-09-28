import SwiftUI

/// The four top-level destinations, in tab-bar order.
enum AppTab: Hashable, CaseIterable {
    case home
    case pantry
    case recipes
    case shopping

    /// Tab title; also the VoiceOver label of the tab.
    var title: LocalizedStringKey {
        switch self {
        case .home: "Home"
        case .pantry: "Pantry"
        case .recipes: "Recipes"
        case .shopping: "Shopping"
        }
    }

    /// SF Symbol shown in the tab bar.
    var symbolName: String {
        switch self {
        case .home: "house"
        case .pantry: "refrigerator"
        case .recipes: "book"
        case .shopping: "cart"
        }
    }
}

/// Switches the selected tab, e.g. Home's "Add what's at home" opening the Pantry. Read it
/// from the environment and call it like a function: `selectTab(.pantry)`.
struct SelectTabAction: Sendable {
    private let select: @MainActor @Sendable (AppTab) -> Void

    /// Creates the action.
    ///
    /// - Parameter select: Makes `tab` the selected tab.
    init(_ select: @escaping @MainActor @Sendable (AppTab) -> Void) {
        self.select = select
    }

    /// Selects `tab`.
    @MainActor
    func callAsFunction(_ tab: AppTab) {
        select(tab)
    }
}

extension EnvironmentValues {
    /// Selects a top-level tab; set by ``RootTabView``, a no-op outside it (previews).
    @Entry var selectTab = SelectTabAction { _ in }
}
