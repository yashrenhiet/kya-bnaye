import SwiftUI

/// A calm, centred explanation shown when a screen has nothing to list yet.
///
/// One headline and one line of purpose, so a tired user immediately knows what the screen
/// is for. VoiceOver reads it as a single element.
struct EmptyStateView: View {
    let symbolName: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        VStack(spacing: Spacing.xLarge) {
            symbol
            VStack(spacing: Spacing.small) {
                Text(title)
                    .font(Typography.headline)
                    .foregroundStyle(ThemeColor.textPrimary.color)
                    .accessibilityAddTraits(.isHeader)
                Text(message)
                    .font(Typography.body)
                    .foregroundStyle(ThemeColor.textSecondary.color)
            }
            .multilineTextAlignment(.center)
        }
        .padding(Spacing.xLarge)
        .frame(maxWidth: Metrics.readableWidth)
        .accessibilityElement(children: .combine)
    }

    private var symbol: some View {
        Image(systemName: symbolName)
            .font(.largeTitle)
            .imageScale(.large)
            .foregroundStyle(ThemeColor.accent.color)
            .padding(Spacing.xLarge)
            .background(Circle().fill(ThemeColor.turmeric.color.opacity(0.22)))
            .accessibilityHidden(true)
    }
}

#Preview {
    EmptyStateView(
        symbolName: "refrigerator", title: "Nothing in your pantry yet",
        message: "Mark what's at home as Plenty, Low or Out. No weighing, no typing."
    )
    .themedScreen()
}
