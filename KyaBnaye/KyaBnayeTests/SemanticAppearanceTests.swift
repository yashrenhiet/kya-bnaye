import KyaCore
import Testing

@testable import KyaBnaye

struct SemanticAppearanceTests {
    @Test("Stock levels are distinguishable without colour")
    func stockLevelsNeverColourOnly() {
        let appearances = StockLevel.allCases.map(\.appearance)
        assertDistinguishableWithoutColour(appearances)
    }

    @Test("Swipe actions are distinguishable without colour")
    func swipeActionsNeverColourOnly() {
        let appearances = SwipeAction.allCases.map(\.appearance)
        assertDistinguishableWithoutColour(appearances)
    }

    private func assertDistinguishableWithoutColour(_ appearances: [SemanticAppearance]) {
        #expect(appearances.allSatisfy { !$0.title.isEmpty && !$0.symbolName.isEmpty })
        #expect(Set(appearances.map(\.title)).count == appearances.count)
        #expect(Set(appearances.map(\.symbolName)).count == appearances.count)
    }
}
