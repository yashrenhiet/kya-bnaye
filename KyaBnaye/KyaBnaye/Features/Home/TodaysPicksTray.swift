import KyaCore
import SwiftUI

/// "Today's picks": today's right swipes (derived from the swipe log, so an undo removes
/// one and the tray clears at midnight). Each row offers "+ list" for missing ingredients
/// and "I made this", which runs the shared cooking flow.
struct TodaysPicksTray: View {
    let store: DeckStore
    let cookFlow: CookFlowStore
    let viewRecipe: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("Today's picks (\(store.picks.count))")
                .font(Typography.headline)
                .foregroundStyle(ThemeColor.textPrimary.color)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("picks.header")
            if store.picks.isEmpty {
                Text("Swipe right on a dish you want, and it waits here for today.")
                    .font(Typography.supporting)
                    .foregroundStyle(ThemeColor.textSecondary.color)
            } else {
                ForEach(store.picks) { row in
                    PickRowView(
                        row: row, isBusy: cookFlow.isBusy,
                        viewRecipe: { viewRecipe(row.recipe.id) },
                        addMissing: { Task { await store.addMissingToShoppingList(row.recipe) } },
                        cook: { Task { await cookFlow.cook(row.recipe) } })
                    if row.id != store.picks.last?.id { Divider() }
                }
            }
        }
        .padding(Spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                .fill(ThemeColor.surface.color))
    }
}

/// One pick: name (opens the recipe), missing count with "+ list", and "I made this" (or
/// "Made" once cooked after picking).
private struct PickRowView: View {
    let row: PickRow
    let isBusy: Bool
    let viewRecipe: () -> Void
    let addMissing: () -> Void
    let cook: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.small) {
                title
                Spacer(minLength: Spacing.small)
                buttons.fixedSize()
            }
            VStack(alignment: .leading, spacing: Spacing.small) {
                title
                buttons
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("picks.row.\(row.id)")
    }

    private var title: some View {
        Button(action: viewRecipe) {
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                Text(row.recipe.name)
                    .font(Typography.body.weight(.semibold))
                    .foregroundStyle(ThemeColor.textPrimary.color)
                Text(statusText)
                    .font(Typography.caption)
                    .foregroundStyle(ThemeColor.textSecondary.color)
            }
            .frame(minHeight: Metrics.minimumTapTarget, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(row.recipe.name)
        .accessibilityValue(statusText)
        .accessibilityHint("Opens the recipe.")
        .accessibilityIdentifier("picks.name.\(row.id)")
    }

    private var buttons: some View {
        HStack(spacing: Spacing.small) {
            if row.missingCount > 0 && !row.pick.isMade {
                Button(action: addMissing) {
                    Label("list", systemImage: "plus")
                        .font(Typography.supporting.weight(.semibold))
                        .frame(
                            minWidth: Metrics.minimumTapTarget, minHeight: Metrics.minimumTapTarget)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Add missing to shopping list")
                .accessibilityIdentifier("picks.addMissing.\(row.id)")
            }
            if row.pick.isMade {
                Label("Made", systemImage: "checkmark.circle.fill")
                    .font(Typography.supporting.weight(.semibold))
                    .foregroundStyle(ThemeColor.stockPlenty.color)
                    .frame(minHeight: Metrics.minimumTapTarget)
            } else {
                Button(action: cook) {
                    Label("I made this", systemImage: "fork.knife")
                        .font(Typography.supporting.weight(.semibold))
                        .frame(minHeight: Metrics.minimumTapTarget)
                }
                .buttonStyle(.primaryAction)
                .disabled(isBusy)
                .accessibilityHint("Adds this dish to your history, then asks what got used up.")
                .accessibilityIdentifier("picks.made.\(row.id)")
            }
        }
    }

    private var statusText: String {
        if row.pick.isMade { return String(localized: "Made today") }
        return row.missingCount == 0
            ? String(localized: "Ready to cook")
            : String(localized: "Missing \(row.missingCount)")
    }
}
