import SwiftUI

/// A capsule chip that is on or off: filter chips, meal and flavour pickers.
///
/// Selection is shown three ways, never by colour alone: a checkmark replaces the symbol,
/// the capsule fills, and the title turns semibold. VoiceOver hears the Selected trait.
struct SelectableChip: View {
    let title: String
    /// Shown when the chip is off; a checkmark replaces it when on. `nil` shows no symbol
    /// when off.
    var symbolName: String?
    let isOn: Bool
    /// Spoken after the title, e.g. "Removes this filter."
    var hint: String?
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            ChipLabel(title: title, symbolName: symbolName, isOn: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityHint(hint ?? "")
    }
}

/// The capsule look shared by every chip, also used as a `Menu` label.
struct ChipLabel: View {
    let title: String
    var symbolName: String?
    let isOn: Bool
    /// Adds a chevron, for a chip that opens a menu.
    var showsDisclosure = false

    var body: some View {
        HStack(spacing: Spacing.xSmall) {
            if let symbol = isOn ? "checkmark" : symbolName {
                Image(systemName: symbol)
                    .accessibilityHidden(true)
            }
            Text(title)
            if showsDisclosure {
                Image(systemName: "chevron.down")
                    .font(Typography.caption)
                    .accessibilityHidden(true)
            }
        }
        .font(Typography.supporting.weight(isOn ? .semibold : .regular))
        .foregroundStyle(isOn ? ThemeColor.onAccent.color : ThemeColor.textPrimary.color)
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.xSmall)
        .frame(minHeight: Metrics.minimumTapTarget)
        .background(Capsule().fill(isOn ? ThemeColor.accent.color : ThemeColor.surface.color))
        .overlay(
            Capsule().strokeBorder(
                isOn ? ThemeColor.accent.color : ThemeColor.textSecondary.color.opacity(0.4))
        )
        .contentShape(Capsule())
    }
}

#Preview {
    HStack {
        SelectableChip(title: "Quick", symbolName: "timer", isOn: true) {}
        SelectableChip(title: "Sweet", isOn: false) {}
    }
    .themedScreen()
}
