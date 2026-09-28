import 'package:kya_core/kya_core.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

void main() {
  group('activeEvents', () {
    test('empty log -> empty list', () {
      expect(activeEvents(const []), isEmpty);
    });

    test('without undo every event is kept, in original order', () {
      final events = [
        swipe('e1', 'a', SwipeAction.right, daysAgo(2)),
        swipe('e2', 'b', SwipeAction.left, daysAgo(1)),
        swipe('e3', 'c', SwipeAction.neverShow, refNow),
      ];
      expect(activeEvents(events), events);
    });

    test('drops the undo event and the event it references', () {
      final e1 = swipe('e1', 'a', SwipeAction.right, daysAgo(1));
      final e2 = swipe('e2', 'b', SwipeAction.left, refNow);
      expect(activeEvents([e1, e2, undo('u1', 'e2', refNow)]), [e1]);
    });

    test('undo order does not matter (log may be unsorted)', () {
      final e1 = swipe('e1', 'a', SwipeAction.right, refNow);
      final e2 = swipe('e2', 'b', SwipeAction.right, refNow);
      expect(activeEvents([undo('u1', 'e1', refNow), e1, e2]), [e2]);
    });

    test('undo of an unknown id removes only the undo itself', () {
      final e1 = swipe('e1', 'a', SwipeAction.right, refNow);
      expect(activeEvents([e1, undo('u1', 'missing', refNow)]), [e1]);
    });

    test('undo with no target is dropped and removes nothing else', () {
      final e1 = swipe('e1', 'a', SwipeAction.right, refNow);
      final bare = swipe('u1', 'a', SwipeAction.undo, refNow);
      expect(activeEvents([e1, bare]), [e1]);
    });

    test('an undo whose target is another undo never resurrects events', () {
      final e1 = swipe('e1', 'a', SwipeAction.neverShow, refNow);
      final result = activeEvents([
        e1,
        undo('u1', 'e1', refNow),
        undo('u2', 'u1', refNow),
      ]);
      expect(result, isEmpty);
    });

    test('several undos each cancel exactly their own target', () {
      final e1 = swipe('e1', 'a', SwipeAction.right, refNow);
      final e2 = swipe('e2', 'b', SwipeAction.right, refNow);
      final e3 = swipe('e3', 'c', SwipeAction.right, refNow);
      final result = activeEvents([
        e1,
        e2,
        e3,
        undo('u1', 'e1', refNow),
        undo('u3', 'e3', refNow),
      ]);
      expect(result, [e2]);
    });

    test('does not mutate the input list', () {
      final events = [
        swipe('e1', 'a', SwipeAction.right, refNow),
        undo('u1', 'e1', refNow),
      ];
      final copy = List<SwipeEvent>.of(events);
      activeEvents(events);
      expect(events, copy);
    });
  });
}
