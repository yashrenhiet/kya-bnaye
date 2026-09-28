import SwiftUI

/// The one filled button per screen ("I made this", "Add what's at home", "Try again").
///
/// Replaces `.borderedProminent`, whose white label fails contrast on the saffron accent in
/// dark mode: the label uses `onAccent`, which meets 4.5:1 on `accent` in both appearances.
/// At least 44 pt tall; dims when disabled and while pressed.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(ThemeColor.onAccent.color)
            .padding(.horizontal, Spacing.large)
            .padding(.vertical, Spacing.small)
            .frame(minHeight: Metrics.minimumTapTarget)
            .background(Capsule().fill(ThemeColor.accent.color))
            .contentShape(Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    /// The filled accent button; see ``PrimaryButtonStyle``.
    static var primaryAction: PrimaryButtonStyle { PrimaryButtonStyle() }
}
