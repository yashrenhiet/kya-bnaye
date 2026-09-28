import KyaCore
import SwiftUI

/// One pantry line: name, expiry badge and level badge. Tapping cycles the level.
///
/// The level is always spoken and shown as text plus a symbol, never by colour alone. At
/// accessibility text sizes the badges go under the name.
struct PantryRowView: View {
    let row: PantryRow
    let cycle: () -> Void

    var body: some View {
        Button(action: cycle) {
            AdaptiveStack { _ in
                Text(row.ingredient.name)
                    .font(Typography.body)
                    .foregroundStyle(ThemeColor.textPrimary.color)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let badge = row.expiryBadge {
                    Label(badge.text, systemImage: badge.symbolName)
                        .font(Typography.caption)
                        .foregroundStyle(ThemeColor.textSecondary.color)
                }
                levelBadge
            }
            .frame(minHeight: Metrics.minimumTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.ingredient.name)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("pantry.row.\(row.id)")
    }

    @ViewBuilder
    private var levelBadge: some View {
        if row.isAssumedStaple {
            Label("Assumed", systemImage: "house")
                .font(Typography.supporting)
                .foregroundStyle(ThemeColor.textSecondary.color)
        } else {
            StatusBadge(
                appearance: row.effectiveLevel.appearance,
                font: Typography.supporting.weight(.semibold))
        }
    }

    private var accessibilityValue: String {
        let level =
            row.isAssumedStaple
            ? String(localized: "Assumed at home") : row.effectiveLevel.appearance.title
        guard let badge = row.expiryBadge else { return level }
        return "\(level), \(badge.accessibilityText)"
    }

    private var accessibilityHint: String {
        let next = PantryRules.nextLevel(after: row.item?.level).appearance.title
        return String(localized: "Double-tap to mark \(next).")
    }
}

/// The All / Low / Expiring chips. The selected chip shows a checkmark and a filled shape,
/// so selection is not conveyed by colour alone.
struct PantryFilterChips: View {
    @Binding var selection: PantryFilter

    var body: some View {
        FlowLayout {
            ForEach(PantryFilter.allCases) { filter in
                chip(filter)
            }
        }
        .padding(.vertical, Spacing.xSmall)
    }

    private func chip(_ filter: PantryFilter) -> some View {
        SelectableChip(
            title: filter.title, isOn: filter == selection, hint: filter.accessibilityHint
        ) {
            selection = filter
        }
        .accessibilityIdentifier("pantry.filter.\(filter.rawValue)")
    }
}
