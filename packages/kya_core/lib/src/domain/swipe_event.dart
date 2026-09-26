import 'package:meta/meta.dart';

/// Which of the two ranking strategies a [SwipeEvent] happened under.
///
/// Recorded on every event (not just derived from context at read time)
/// because the taste profile explanation logic
/// (`docs/design/RECOMMENDER.md` section 6) sometimes needs to know which
/// mode taught it a given preference.
enum SwipeMode { kitchen, craving }

enum SwipeAction { right, left, neverShow, undo }

/// One swipe, forever. The event log is **append-only** (ADR 008): undo is
/// a new [SwipeAction.undo] event that references the event it reverses,
/// never a delete. `TasteProfile` is folded from the full list of these —
/// see `docs/design/RECOMMENDER.md` section 4.
@immutable
class SwipeEvent {
  const SwipeEvent({
    required this.id,
    required this.recipeId,
    required this.action,
    required this.mode,
    required this.at,
    required this.deckSeed,
    this.undoesEventId,
  });

  final String id;
  final String recipeId;
  final SwipeAction action;
  final SwipeMode mode;
  final DateTime at;

  /// The seed the deck was built with when this card was shown — lets a
  /// [SwipeAction.undo] event, and golden tests, reconstruct exactly what
  /// the user saw (`docs/design/RECOMMENDER.md` section 4, DeckBuilder).
  final int deckSeed;

  /// Set only when [action] is [SwipeAction.undo]: the id of the event being
  /// reverted.
  final String? undoesEventId;

  @override
  bool operator ==(Object other) =>
      other is SwipeEvent &&
      other.id == id &&
      other.recipeId == recipeId &&
      other.action == action &&
      other.mode == mode &&
      other.at == at &&
      other.deckSeed == deckSeed &&
      other.undoesEventId == undoesEventId;

  @override
  int get hashCode =>
      Object.hash(id, recipeId, action, mode, at, deckSeed, undoesEventId);

  @override
  String toString() => 'SwipeEvent($action $recipeId @ $at)';
}
