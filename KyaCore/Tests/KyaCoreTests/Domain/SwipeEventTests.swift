import Foundation
import KyaCore
import Testing

@Suite("SwipeEvent")
struct SwipeEventTests {
    private let at: Date

    init() throws {
        at = try TestDates.utc(2025, 6, 1, 12)
    }

    private func event(
        id: String = "e1",
        recipeId: String = "poha",
        action: SwipeAction = .right,
        mode: SwipeMode = .kitchen,
        when: Date? = nil,
        deckSeed: Int = 7,
        undoesEventId: String? = nil
    ) -> SwipeEvent {
        SwipeEvent(
            id: id,
            recipeId: recipeId,
            action: action,
            mode: mode,
            at: when ?? at,
            deckSeed: deckSeed,
            undoesEventId: undoesEventId
        )
    }

    @Test("undoesEventId defaults to nil")
    func undoesDefaultsNil() {
        #expect(event().undoesEventId == nil)
    }

    @Test("an undo event references the event it reverses")
    func undoReferences() {
        let undo = event(id: "e2", action: .undo, undoesEventId: "e1")

        #expect(undo.action == .undo)
        #expect(undo.undoesEventId == "e1")
    }

    // MARK: equality

    @Test("events with identical fields are equal with equal hashes")
    func equalEvents() {
        let a = event(undoesEventId: "e0")
        let b = event(undoesEventId: "e0")

        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test("differs when any single field differs")
    func anyFieldDiffers() {
        let base = event()

        #expect(event(id: "e2") != base)
        #expect(event(recipeId: "upma") != base)
        #expect(event(action: .left) != base)
        #expect(event(mode: .craving) != base)
        #expect(event(when: at.addingTimeInterval(0.001)) != base)
        #expect(event(deckSeed: 8) != base)
        #expect(event(undoesEventId: "e0") != base)
    }

    /// Deliberate divergence from the Dart oracle, where `DateTime` equality
    /// includes the `isUtc` flag: `Date` is a bare instant with no zone flag.
    @Test("the same instant built in different zones is equal")
    func sameInstantAnyZone() throws {
        let kolkata = try TestDates.calendar(zone: "Asia/Kolkata")
        let sameInstant = try TestDates.local(2025, 6, 1, 17, 30, calendar: kolkata)

        #expect(event(when: sameInstant) == event())
    }

    @Test("description shows action, recipe and UTC time in Dart's format")
    func description() {
        #expect(
            event().description == "SwipeEvent(SwipeAction.right poha @ 2025-06-01 12:00:00.000Z)")
    }

    @Test("SwipeAction and SwipeMode expose the documented closed sets")
    func closedSets() {
        #expect(SwipeAction.allCases == [.right, .left, .neverShow, .undo])
        #expect(SwipeMode.allCases == [.kitchen, .craving])
    }
}
