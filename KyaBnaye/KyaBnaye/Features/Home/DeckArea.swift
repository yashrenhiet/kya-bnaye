import KyaCore
import SwiftUI

/// The top card with its swipe gesture, overflow menu and VoiceOver actions, plus the
/// on-screen buttons that mirror every gesture: Not today · Undo · Want this.
///
/// Drag right = Want this, left = Not today. The card follows the finger with rotation, and
/// a "Want this" / "Not today" stamp (icon and text) fades in with the drag. Past the
/// threshold it flings off; with Reduce Motion it fades out instead, and never rotates.
struct DeckArea: View {
    let store: DeckStore
    let card: ScoredRecipe

    /// A swipe asked for by a button, played on the card as if it were dragged.
    @State private var requested: SwipeAction?

    var body: some View {
        VStack(spacing: Spacing.large) {
            SwipeableCard(store: store, card: card, requested: $requested)
                .id(card.recipe.id)
            DeckControls(store: store, hasCard: true) { requested = $0 }
        }
    }
}

/// The on-screen swipe buttons. Also shown at the end of the deck, where only Undo is live.
struct DeckControls: View {
    let store: DeckStore
    let hasCard: Bool
    /// Plays a Want this / Not today swipe on the top card.
    let swipe: (SwipeAction) -> Void

    var body: some View {
        HStack(spacing: Spacing.medium) {
            button(.left, identifier: "deck.skip") { swipe(.left) }
                .disabled(!hasCard || store.isWriting)
            button(.undo, identifier: "deck.undo") { Task { await store.undo() } }
                .disabled(!store.canUndo)
            button(.right, identifier: "deck.want", prominent: true) { swipe(.right) }
                .disabled(!hasCard || store.isWriting)
        }
    }

    private func button(
        _ action: SwipeAction, identifier: String, prominent: Bool = false,
        perform: @escaping () -> Void
    ) -> some View {
        let appearance = action.appearance
        return Button(action: perform) {
            VStack(spacing: Spacing.xSmall) {
                Image(systemName: appearance.symbolName)
                    .font(Typography.headline)
                    .accessibilityHidden(true)
                Text(appearance.title)
                    .font(Typography.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(prominent ? ThemeColor.onAccent.color : appearance.color.color)
            .frame(maxWidth: .infinity, minHeight: Metrics.minimumTapTarget + Spacing.large)
            .background(
                RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                    .fill(prominent ? ThemeColor.accent.color : ThemeColor.surface.color))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(appearance.title)
        .accessibilityIdentifier(identifier)
    }
}

/// The draggable top card. Owns only the transient drag state; every decision goes through
/// the store.
private struct SwipeableCard: View {
    let store: DeckStore
    let card: ScoredRecipe
    @Binding var requested: SwipeAction?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset: CGFloat = 0
    @State private var opacity = 1.0
    @State private var committed: SwipeAction?

    /// Horizontal travel that commits a swipe.
    private static let threshold: CGFloat = 110
    /// How far a committed card travels before it is removed.
    private static let flingDistance: CGFloat = 700

    var body: some View {
        movingCard
            .onChange(of: requested) { _, action in
                guard let action else { return }
                requested = nil
                fling(action)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(card.recipe.name)
            .accessibilityValue(DeckCardView.accessibilityValue(for: card))
            .accessibilityHint("Swipe right with one finger for Want this, left for Not today.")
            .accessibilityAction(named: SwipeAction.right.appearance.title) { fling(.right) }
            .accessibilityAction(named: SwipeAction.left.appearance.title) { fling(.left) }
            .accessibilityAction(named: String(localized: "Never show this dish")) {
                fling(.neverShow)
            }
            .accessibilityActions {
                if store.canUndo {
                    Button(SwipeAction.undo.appearance.title) { Task { await store.undo() } }
                }
            }
            .accessibilityIdentifier("deck.card")
            .sensoryFeedback(.selection, trigger: abs(offset) > Self.threshold)
            .sensoryFeedback(trigger: committed) { _, action in
                switch action {
                case .right: .success
                case .left: .impact(weight: .light)
                case .neverShow: .warning
                case .undo, nil: nil
                }
            }
    }

    /// The card, its stamp and menu, following the drag.
    private var movingCard: some View {
        let rotation = Angle.degrees(reduceMotion ? 0 : Double(offset / 20))
        return DeckCardView(card: card)
            .overlay(alignment: .top) { stamp }
            .overlay(alignment: .topTrailing) { overflowMenu }
            .offset(x: offset)
            .rotationEffect(rotation, anchor: .bottom)
            .opacity(opacity)
            .horizontalPan(changed: dragChanged, ended: dragEnded)
    }

    /// Only a drag that starts out horizontal moves the card; a vertical one scrolls Home.
    private func dragChanged(_ translation: CGFloat) {
        guard committed == nil else { return }
        offset = translation
    }

    /// Flings the card past the threshold (or on a quick flick); otherwise it springs back.
    private func dragEnded(_ translation: CGFloat, _ velocity: CGFloat) {
        guard committed == nil else { return }
        // Where a flick would carry the card, as `DragGesture` predicts it.
        let travel = translation + velocity * 0.25
        if abs(translation) > Self.threshold || abs(travel) > Self.threshold * 2 {
            fling(travel > 0 ? .right : .left)
        } else {
            withAnimation(reduceMotion ? nil : .spring(duration: 0.3)) { offset = 0 }
        }
    }

    /// Animates the card away (fling, or fade with Reduce Motion), then logs the swipe. If
    /// the store keeps the card (the write failed), it slides back.
    private func fling(_ action: SwipeAction) {
        guard committed == nil, !store.isWriting else { return }
        committed = action
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .easeIn(duration: 0.22)) {
            switch action {
            case .right where !reduceMotion: offset = Self.flingDistance
            case .left where !reduceMotion: offset = -Self.flingDistance
            default: opacity = 0
            }
        } completion: {
            Task {
                await store.swipe(action, expectedTopId: card.recipe.id)
                guard store.cards.first?.recipe.id == card.recipe.id else { return }
                committed = nil
                withAnimation(reduceMotion ? nil : .spring(duration: 0.3)) {
                    offset = 0
                    opacity = 1
                }
            }
        }
    }

    @ViewBuilder
    private var stamp: some View {
        let progress = min(abs(offset) / Self.threshold, 1)
        if offset != 0 {
            let appearance = (offset > 0 ? SwipeAction.right : .left).appearance
            Label(appearance.title, systemImage: appearance.symbolName)
                .font(Typography.headline)
                .foregroundStyle(appearance.color.color)
                .padding(.horizontal, Spacing.large)
                .padding(.vertical, Spacing.small)
                .background(Capsule().fill(ThemeColor.surface.color))
                .overlay(Capsule().strokeBorder(appearance.color.color, lineWidth: 2))
                .padding(.top, Spacing.xLarge)
                .opacity(Double(progress))
                .accessibilityHidden(true)
        }
    }

    private var overflowMenu: some View {
        Menu {
            Button(role: .destructive) {
                fling(.neverShow)
            } label: {
                Label(
                    "Never show this dish", systemImage: SwipeAction.neverShow.appearance.symbolName
                )
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(Typography.headline)
                .foregroundStyle(ThemeColor.textPrimary.color)
                .frame(width: Metrics.minimumTapTarget, height: Metrics.minimumTapTarget)
                .background(Circle().fill(ThemeColor.surface.color.opacity(0.9)))
        }
        .padding(Spacing.large)
        .accessibilityLabel("More options")
        .accessibilityIdentifier("deck.more")
    }
}
