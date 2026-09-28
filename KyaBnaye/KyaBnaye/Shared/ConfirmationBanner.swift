import SwiftUI

/// A short confirmation ("Added 3 to your shopping list") that slides in at the bottom,
/// is announced to VoiceOver, and clears itself after a few seconds. Fades instead of
/// sliding when Reduce Motion is on. Place it in a `.safeAreaInset(edge: .bottom)`.
struct ConfirmationBanner: View {
    @Binding var message: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let visibleFor: Duration = .seconds(3)

    var body: some View {
        Group {
            if let message {
                Label(message, systemImage: "checkmark.circle.fill")
                    .font(Typography.supporting.weight(.semibold))
                    .foregroundStyle(ThemeColor.onAccent.color)
                    .padding(.horizontal, Spacing.large)
                    .padding(.vertical, Spacing.small)
                    .frame(minHeight: Metrics.minimumTapTarget)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                            .fill(ThemeColor.accent.color)
                    )
                    .padding(.horizontal, Spacing.large)
                    .padding(.bottom, Spacing.small)
                    .transition(
                        reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity)
                    )
                    .accessibilityIdentifier("banner")
                    .task(id: message) {
                        AccessibilityNotification.Announcement(message).post()
                        try? await Task.sleep(for: Self.visibleFor)
                        guard !Task.isCancelled else { return }
                        self.message = nil
                    }
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: message)
    }
}

#Preview {
    Color.clear
        .safeAreaInset(edge: .bottom) {
            ConfirmationBanner(message: .constant("Added 3 to your shopping list"))
        }
        .themedScreen()
}
