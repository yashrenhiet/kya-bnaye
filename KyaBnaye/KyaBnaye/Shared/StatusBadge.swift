import KyaCore
import SwiftUI

/// A small state label (stock level, "Ready" / "2 missing", a deck tier): symbol and text
/// always, colour only as a third cue, so meaning never rests on colour alone.
struct StatusBadge: View {
    /// How the badge is drawn.
    enum Style {
        /// Tinted symbol and text.
        case plain
        /// Upper-case text inside a tinted outline, for the deck card.
        case outlined
    }

    let appearance: SemanticAppearance
    var style: Style = .plain
    var font: Font = Typography.caption.weight(.semibold)

    var body: some View {
        switch style {
        case .plain:
            label
        case .outlined:
            label
                .textCase(.uppercase)
                .padding(.horizontal, Spacing.small)
                .padding(.vertical, Spacing.xSmall)
                .background(Capsule().strokeBorder(appearance.color.color, lineWidth: 1))
        }
    }

    private var label: some View {
        Label(appearance.title, systemImage: appearance.symbolName)
            .labelStyle(.titleAndIcon)
            .font(font)
            .foregroundStyle(appearance.color.color)
    }
}

#Preview {
    VStack {
        StatusBadge(appearance: StockLevel.low.appearance)
        StatusBadge(appearance: StockLevel.plenty.appearance, style: .outlined)
    }
    .themedScreen()
}
