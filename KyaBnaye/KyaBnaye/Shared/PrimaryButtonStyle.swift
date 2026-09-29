import SwiftUI

/// The one filled button per screen ("I made this", "Add what's at home", "Try again").
///
/// Replaces `.borderedProminent`, whose white label fails contrast on the saffron accent in
/// dark mode: the label uses `onAccent`, which meets 4.5:1 on `accent` in both appearances.
/// At least 44 pt tall; dims when disabled and, slightly, while pressed (``pressedOpacity``
/// keeps the label at 4.5:1 even mid-press).
struct PrimaryButtonStyle: ButtonStyle {
    /// Opacity while pressed; lower values drop the label under 4.5:1 in light mode.
    static let pressedOpacity = 0.9

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(ThemeColor.onAccent.color)
            .padding(.horizontal, Spacing.large)
            .padding(.vertical, Spacing.small)
            .frame(minHeight: Metrics.minimumTapTarget)
            .background(Capsule().fill(ThemeColor.accent.color))
            .contentShape(Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? Self.pressedOpacity : 1) : 0.45)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    /// The filled accent button; see ``PrimaryButtonStyle``.
    static var primaryAction: PrimaryButtonStyle { PrimaryButtonStyle() }
}
