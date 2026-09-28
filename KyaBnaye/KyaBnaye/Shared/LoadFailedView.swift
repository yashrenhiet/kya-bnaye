import SwiftUI

/// The recoverable error state for a screen whose data could not be read: what failed, a
/// reassurance, the underlying reason in small print, and a "Try again" button.
///
/// Scrolls when the text is too large for the screen (accessibility sizes), so the button
/// is always reachable.
struct LoadFailedView: View {
    /// What failed, e.g. "Couldn't load your pantry".
    let title: LocalizedStringKey
    /// A calm next step for the user.
    var reassurance: LocalizedStringKey = "Your data is safe. Please try again."
    /// The underlying reason, shown verbatim in small print.
    let detail: String
    /// Whether it scrolls on its own; pass `false` inside a screen that already scrolls.
    var scrolls = true
    /// Starts loading again.
    let retry: () -> Void

    var body: some View {
        if scrolls {
            CenteredScrollView { content }
        } else {
            content
        }
    }

    private var content: some View {
        VStack(spacing: Spacing.large) {
            EmptyStateView(
                symbolName: "exclamationmark.triangle", title: title, message: reassurance)
            Text(verbatim: detail)
                .font(Typography.caption)
                .foregroundStyle(ThemeColor.textSecondary.color)
                .multilineTextAlignment(.center)
            Button(action: retry) {
                Text("Try again")
                    .frame(minWidth: Metrics.minimumTapTarget * 3)
            }
            .buttonStyle(.primaryAction)
            .accessibilityIdentifier("state.retry")
        }
        .padding(Spacing.xLarge)
    }
}

#Preview {
    LoadFailedView(title: "Couldn't load your pantry", detail: "The disk is full.") {}
        .themedScreen()
}
