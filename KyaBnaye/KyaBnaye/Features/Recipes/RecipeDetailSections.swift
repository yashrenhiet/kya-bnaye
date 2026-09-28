import KyaCore
import SwiftUI

/// The ingredient list with have / missing / assumed / optional marks (icon + text), and
/// "Add missing to shopping list" when something is missing.
struct RecipeIngredientsSection: View {
    let cookability: RecipeCookability
    let addMissing: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            RecipeSectionTitle(title: "Ingredients")
            VStack(alignment: .leading, spacing: Spacing.small) {
                ForEach(Array(cookability.lines.enumerated()), id: \.offset) { _, entry in
                    RecipeIngredientLine(entry: entry)
                }
            }
            if cookability.lines.contains(where: { $0.status == .assumedStaple }) {
                Text("Staples like salt and oil are assumed at home unless marked Out.")
                    .font(Typography.caption)
                    .foregroundStyle(ThemeColor.textSecondary.color)
            }
            if !cookability.isReady {
                Button(action: addMissing) {
                    Label(
                        "Add \(cookability.missingCount) missing to shopping list",
                        systemImage: "cart.badge.plus"
                    )
                    .frame(maxWidth: .infinity, minHeight: Metrics.minimumTapTarget)
                }
                .buttonStyle(.bordered)
                .tint(ThemeColor.accent.color)
                .accessibilityIdentifier("recipe.addMissing")
            }
        }
    }
}

/// One ingredient line: status icon, name, quantity and the status in words.
private struct RecipeIngredientLine: View {
    let entry: RecipeLineAvailability

    var body: some View {
        let look = entry.status.recipeAppearance
        AdaptiveStack(spacing: Spacing.small, alignment: .firstTextBaseline) { isStacked in
            HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                Image(systemName: look.symbolName)
                    .foregroundStyle(look.color.color)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    Text(name)
                        .font(Typography.body)
                        .foregroundStyle(ThemeColor.textPrimary.color)
                    if !entry.line.quantityText.isEmpty {
                        Text(entry.line.quantityText)
                            .font(Typography.caption)
                            .foregroundStyle(ThemeColor.textSecondary.color)
                    }
                }
            }
            if !isStacked { Spacer(minLength: Spacing.small) }
            Text(look.title)
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(look.color.color)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityValue("\(entry.line.quantityText), \(look.title)")
    }

    private var name: String {
        entry.ingredient?.name ?? entry.line.ingredientId
    }
}

extension RecipeLineStatus {
    /// Text, symbol and tint for an ingredient line; the text always carries the meaning.
    var recipeAppearance: SemanticAppearance {
        switch self {
        case .have:
            SemanticAppearance(
                title: String(localized: "Have"), symbolName: "checkmark.circle.fill",
                color: .stockPlenty)
        case .missing:
            SemanticAppearance(
                title: String(localized: "Missing"), symbolName: "xmark.circle.fill",
                color: .stockOut)
        case .assumedStaple:
            SemanticAppearance(
                title: String(localized: "Assumed"), symbolName: "checkmark.circle",
                color: .textSecondary)
        case .optional:
            SemanticAppearance(
                title: String(localized: "Optional"), symbolName: "circle.dashed",
                color: .textSecondary)
        }
    }
}

/// Numbered cooking steps.
struct RecipeStepsSection: View {
    let steps: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            RecipeSectionTitle(title: "Steps")
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: Spacing.medium) {
                    Text("\(index + 1)")
                        .font(Typography.body.weight(.bold))
                        .foregroundStyle(ThemeColor.accent.color)
                        .frame(minWidth: Spacing.xLarge, alignment: .trailing)
                    Text(step)
                        .font(Typography.body)
                        .foregroundStyle(ThemeColor.textPrimary.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Step \(index + 1): \(step)")
            }
        }
    }
}

/// A section headline on the detail screen.
private struct RecipeSectionTitle: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(Typography.headline)
            .foregroundStyle(ThemeColor.textPrimary.color)
            .accessibilityAddTraits(.isHeader)
    }
}
