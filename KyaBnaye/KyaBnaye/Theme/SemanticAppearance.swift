import KyaCore

/// How a semantic state is shown: always a title and a symbol, with colour as a third cue.
///
/// Colour alone never carries meaning (WCAG 1.4.1), so every state has a distinct symbol and
/// a text title that VoiceOver can read.
struct SemanticAppearance: Equatable, Sendable {
    /// Short user-facing name of the state.
    let title: String
    /// SF Symbol name, distinct per state within its family.
    let symbolName: String
    /// Tint for the symbol and title.
    let color: ThemeColor
}

extension StockLevel {
    /// The badge appearance for this stock level.
    var appearance: SemanticAppearance {
        switch self {
        case .plenty:
            SemanticAppearance(
                title: String(localized: "Plenty"), symbolName: "checkmark.circle.fill",
                color: .stockPlenty)
        case .low:
            SemanticAppearance(
                title: String(localized: "Low"), symbolName: "exclamationmark.circle.fill",
                color: .stockLow)
        case .out:
            SemanticAppearance(
                title: String(localized: "Out"), symbolName: "xmark.circle.fill",
                color: .stockOut)
        }
    }
}

extension RecipeCookability {
    /// "Ready" (check) or "N missing" (cart), with `title` as the words to show.
    func appearance(title: String) -> SemanticAppearance {
        isReady
            ? SemanticAppearance(
                title: title, symbolName: "checkmark.circle.fill", color: .stockPlenty)
            : SemanticAppearance(title: title, symbolName: "cart", color: .stockLow)
    }
}

extension SwipeAction {
    /// The appearance of the button and swipe overlay for this action.
    var appearance: SemanticAppearance {
        switch self {
        case .right:
            SemanticAppearance(
                title: String(localized: "Want this"), symbolName: "heart.fill",
                color: .swipeWant)
        case .left:
            SemanticAppearance(
                title: String(localized: "Not today"), symbolName: "hand.wave",
                color: .swipeSkip)
        case .neverShow:
            SemanticAppearance(
                title: String(localized: "Never show"), symbolName: "eye.slash",
                color: .swipeNever)
        case .undo:
            SemanticAppearance(
                title: String(localized: "Undo"), symbolName: "arrow.uturn.backward",
                color: .textSecondary)
        }
    }
}
