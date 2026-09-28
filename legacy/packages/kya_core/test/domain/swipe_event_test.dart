import 'package:kya_core/kya_core.dart';
import 'package:test/test.dart';

void main() {
  final at = DateTime.utc(2025, 6, 1, 12);

  SwipeEvent event({
    String id = 'e1',
    String recipeId = 'poha',
    SwipeAction action = SwipeAction.right,
    SwipeMode mode = SwipeMode.kitchen,
    DateTime? when,
    int deckSeed = 7,
    String? undoesEventId,
  }) => SwipeEvent(
    id: id,
    recipeId: recipeId,
    action: action,
    mode: mode,
    at: when ?? at,
    deckSeed: deckSeed,
    undoesEventId: undoesEventId,
  );

  group('SwipeEvent', () {
    test('undoesEventId defaults to null', () {
      expect(event().undoesEventId, isNull);
    });

    test('an undo event references the event it reverses', () {
      final undo = event(
        id: 'e2',
        action: SwipeAction.undo,
        undoesEventId: 'e1',
      );

      expect(undo.action, SwipeAction.undo);
      expect(undo.undoesEventId, 'e1');
    });

    group('equality', () {
      test('events with identical fields are equal with equal hashCodes', () {
        final a = event(undoesEventId: 'e0');
        final b = event(undoesEventId: 'e0');

        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
      });

      test('differs when any single field differs', () {
        final base = event();

        expect(event(id: 'e2'), isNot(equals(base)));
        expect(event(recipeId: 'upma'), isNot(equals(base)));
        expect(event(action: SwipeAction.left), isNot(equals(base)));
        expect(event(mode: SwipeMode.craving), isNot(equals(base)));
        expect(
          event(when: at.add(const Duration(milliseconds: 1))),
          isNot(equals(base)),
        );
        expect(event(deckSeed: 8), isNot(equals(base)));
        expect(event(undoesEventId: 'e0'), isNot(equals(base)));
      });

      test('the same instant in UTC and local time are not equal', () {
        // DateTime equality includes isUtc, so persistence must round-trip
        // the zone flag, not just the instant.
        expect(event(when: at.toLocal()), isNot(equals(event())));
      });
    });

    test('toString shows action, recipe and time', () {
      expect(event().toString(), 'SwipeEvent(SwipeAction.right poha @ $at)');
    });
  });

  test('SwipeAction and SwipeMode expose the documented closed sets', () {
    expect(SwipeAction.values, [
      SwipeAction.right,
      SwipeAction.left,
      SwipeAction.neverShow,
      SwipeAction.undo,
    ]);
    expect(SwipeMode.values, [SwipeMode.kitchen, SwipeMode.craving]);
  });
}
