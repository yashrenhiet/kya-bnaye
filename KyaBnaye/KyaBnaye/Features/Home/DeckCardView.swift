import KyaCore
import SwiftUI

/// One dish card: the artwork as hero, the dish name as the loudest text, then time and
/// badge, the one-line reason, and "Have X of Y ingredients". Purely visual; gestures,
/// VoiceOver actions and the overflow menu are added by ``DeckArea``.
struct DeckCardView: View {
    let card: ScoredRecipe

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            RecipeArtwork(
                recipeId: card.recipe.id, name: card.recipe.name, imageAsset: card.recipe.imageAsset
            )
            .aspectRatio(3 / 2, contentMode: .fit)
            Text(card.recipe.name)
                .font(Typography.display)
                .foregroundStyle(ThemeColor.textPrimary.color)
                .fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.medium) {
                    badge
                    Spacer(minLength: Spacing.small)
                    minutes
                }
                VStack(alignment: .leading, spacing: Spacing.small) {
                    badge
                    minutes
                }
            }
            Text(card.explanation)
                .font(Typography.supporting)
                .foregroundStyle(ThemeColor.textSecondary.color)
                .fixedSize(horizontal: false, vertical: true)
            Label(card.haveText, systemImage: "basket")
                .font(Typography.caption)
                .foregroundStyle(ThemeColor.textSecondary.color)
        }
        .padding(Spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                .fill(ThemeColor.surface.color)
                .shadow(color: ThemeColor.textPrimary.color.opacity(0.12), radius: 12, y: 6))
    }

    @ViewBuilder
    private var badge: some View {
        if let badge = card.badge {
            StatusBadge(
                appearance: badge, style: .outlined, font: Typography.caption.weight(.bold))
        }
    }

    private var minutes: some View {
        Label("\(card.recipe.minutes) min", systemImage: "clock")
            .font(Typography.supporting)
            .foregroundStyle(ThemeColor.textSecondary.color)
    }
}

extension DeckCardView {
    /// The single VoiceOver value for a card: badge, time, reason and ingredient count.
    static func accessibilityValue(for card: ScoredRecipe) -> String {
        var parts: [String] = []
        if let badge = card.badge { parts.append(badge.title) }
        parts.append(String(localized: "\(card.recipe.minutes) minutes"))
        parts.append(card.explanation)
        parts.append(card.haveText)
        return parts.joined(separator: ", ")
    }
}
