import Foundation
import KyaCore
import Testing

@testable import KyaBnaye

@Suite("SwipeLogMirror")
struct SwipeLogMirrorTests {
    private let now = DeckTestFixtures.weekdayDinner

    private func event(_ id: String, at: Date) -> SwipeEvent {
        SwipeEvent(id: id, recipeId: "poha", action: .right, mode: .kitchen, at: at, deckSeed: 1)
    }

    @Test("a stale snapshot does not drop an event just written")
    func keepsUnconfirmed() {
        var log = SwipeLogMirror()
        let old = event("a", at: now.addingTimeInterval(-60))
        log.merge([old], now: now)
        let written = event("b", at: now)

        log.record(written)
        log.merge([old], now: now)

        #expect(log.events == [old, written])
    }

    @Test("once a snapshot shows the event it is not duplicated")
    func confirmsOnce() {
        var log = SwipeLogMirror()
        let written = event("b", at: now)
        log.record(written)
        log.merge([written], now: now)
        log.merge([written], now: now)
        #expect(log.events == [written])
    }

    @Test("an unconfirmed event is dropped after the grace period, e.g. after erase all")
    func dropsAfterGrace() {
        var log = SwipeLogMirror()
        log.record(event("b", at: now))
        log.merge([], now: now.addingTimeInterval(SwipeLogMirror.writeGrace + 1))
        #expect(log.events.isEmpty)
    }
}
