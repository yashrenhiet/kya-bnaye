import Foundation
import KyaCore
import Testing

private typealias F = CoreFixtures

/// Port of `legacy/packages/kya_core/test/recommend/core/active_events_test.dart`.
@Suite("SwipeEvent.activeEvents")
struct ActiveEventsTests {
    @Test("empty log -> empty list")
    func emptyLog() {
        #expect(SwipeEvent.activeEvents([]).isEmpty)
    }

    @Test("without undo every event is kept, in original order")
    func noUndo() {
        let events = [
            F.swipe("e1", "a", .right, F.daysAgo(2)),
            F.swipe("e2", "b", .left, F.daysAgo(1)),
            F.swipe("e3", "c", .neverShow, F.refNow),
        ]
        #expect(SwipeEvent.activeEvents(events) == events)
    }

    @Test("drops the undo event and the event it references")
    func dropsUndoAndTarget() {
        let e1 = F.swipe("e1", "a", .right, F.daysAgo(1))
        let e2 = F.swipe("e2", "b", .left, F.refNow)
        #expect(SwipeEvent.activeEvents([e1, e2, F.undo("u1", "e2", F.refNow)]) == [e1])
    }

    @Test("undo order does not matter (log may be unsorted)")
    func unsortedLog() {
        let e1 = F.swipe("e1", "a", .right, F.refNow)
        let e2 = F.swipe("e2", "b", .right, F.refNow)
        #expect(SwipeEvent.activeEvents([F.undo("u1", "e1", F.refNow), e1, e2]) == [e2])
    }

    @Test("undo of an unknown id removes only the undo itself")
    func unknownTarget() {
        let e1 = F.swipe("e1", "a", .right, F.refNow)
        #expect(SwipeEvent.activeEvents([e1, F.undo("u1", "missing", F.refNow)]) == [e1])
    }

    @Test("undo with no target is dropped and removes nothing else")
    func bareUndo() {
        let e1 = F.swipe("e1", "a", .right, F.refNow)
        let bare = F.swipe("u1", "a", .undo, F.refNow)
        #expect(SwipeEvent.activeEvents([e1, bare]) == [e1])
    }

    @Test("an undo whose target is another undo never resurrects events")
    func undoOfUndo() {
        let e1 = F.swipe("e1", "a", .neverShow, F.refNow)
        let result = SwipeEvent.activeEvents([
            e1, F.undo("u1", "e1", F.refNow), F.undo("u2", "u1", F.refNow),
        ])
        #expect(result.isEmpty)
    }

    @Test("several undos each cancel exactly their own target")
    func severalUndos() {
        let e1 = F.swipe("e1", "a", .right, F.refNow)
        let e2 = F.swipe("e2", "b", .right, F.refNow)
        let e3 = F.swipe("e3", "c", .right, F.refNow)
        let result = SwipeEvent.activeEvents([
            e1, e2, e3, F.undo("u1", "e1", F.refNow), F.undo("u3", "e3", F.refNow),
        ])
        #expect(result == [e2])
    }

    @Test("does not mutate the input list")
    func noMutation() {
        let events = [F.swipe("e1", "a", .right, F.refNow), F.undo("u1", "e1", F.refNow)]
        let copy = events
        _ = SwipeEvent.activeEvents(events)
        #expect(events == copy)
    }
}
