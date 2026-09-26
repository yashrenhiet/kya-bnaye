import 'package:kya_core/src/domain/swipe_event.dart';

/// Filters an event log down to the events that still "count": undo events
/// themselves are dropped, and so is whatever event they undid.
///
/// Extracted as a single shared helper — rather than reimplemented in both
/// `taste_profile.dart` and `ranking_context.dart` — because "how undo
/// interacts with the append-only log" (ADR 008) is exactly the kind of
/// rule that must have one implementation, not two that could drift apart.
List<SwipeEvent> activeEvents(List<SwipeEvent> events) {
  final undoneIds = <String>{
    for (final e in events)
      if (e.action == SwipeAction.undo && e.undoesEventId != null)
        e.undoesEventId!,
  };
  return [
    for (final e in events)
      if (e.action != SwipeAction.undo && !undoneIds.contains(e.id)) e,
  ];
}
