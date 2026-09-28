import Foundation
import KyaCore
import Testing

@Suite("RecipeUnhide")
struct RecipeUnhideTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func event(
        _ id: String, _ recipeId: String, _ action: SwipeAction, undoes: String? = nil,
        mode: SwipeMode = .kitchen, seed: Int = 7
    ) -> SwipeEvent {
        SwipeEvent(
            id: id, recipeId: recipeId, action: action, mode: mode,
            at: Date(timeIntervalSince1970: 10), deckSeed: seed, undoesEventId: undoes)
    }

    private func ids() -> () -> String {
        var counter = 0
        return {
            counter += 1
            return "undo\(counter)"
        }
    }

    @Test("undoes the active never-show, copying its mode and seed")
    func undoesNeverShow() {
        let log = [event("n1", "poha", .neverShow, mode: .craving, seed: 42)]
        let undos = RecipeUnhide.undoEvents(for: "poha", in: log, now: now, nextId: ids())
        #expect(
            undos == [
                SwipeEvent(
                    id: "undo1", recipeId: "poha", action: .undo, mode: .craving, at: now,
                    deckSeed: 42, undoesEventId: "n1")
            ])
    }

    @Test("after appending the undos, the dish is no longer excluded by the log")
    func clearsHardExclusion() {
        let log = [event("n1", "poha", .neverShow), event("r1", "poha", .right)]
        let undos = RecipeUnhide.undoEvents(for: "poha", in: log, now: now, nextId: ids())
        let active = SwipeEvent.activeEvents(log + undos)
        #expect(!active.contains { $0.action == .neverShow })
        #expect(active.map(\.id) == ["r1"])
    }

    @Test("ignores never-shows already undone, other recipes and other actions")
    func ignoresInactive() {
        let log = [
            event("n1", "poha", .neverShow), event("u1", "poha", .undo, undoes: "n1"),
            event("n2", "upma", .neverShow), event("l1", "poha", .left),
        ]
        #expect(RecipeUnhide.undoEvents(for: "poha", in: log, now: now, nextId: ids()).isEmpty)
    }

    @Test("undoes every active never-show of the recipe, in log order")
    func undoesAll() {
        let log = [event("n1", "poha", .neverShow), event("n2", "poha", .neverShow)]
        let undos = RecipeUnhide.undoEvents(for: "poha", in: log, now: now, nextId: ids())
        #expect(undos.map(\.undoesEventId) == ["n1", "n2"])
        #expect(undos.map(\.id) == ["undo1", "undo2"])
    }

    @Test("an empty log needs no change")
    func emptyLog() {
        #expect(RecipeUnhide.undoEvents(for: "poha", in: [], now: now, nextId: ids()).isEmpty)
    }
}
