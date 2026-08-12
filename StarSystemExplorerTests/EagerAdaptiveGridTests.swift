import CoreGraphics
import Testing
@testable import StarSystemExplorer

struct EagerAdaptiveGridTests {
    private let grid = EagerAdaptiveGrid(
        minimumColumnWidth: 100,
        horizontalSpacing: 10,
        verticalSpacing: 8
    )

    @Test func addsColumnsOnlyWhenTheMinimumWidthsAndSpacingFit() {
        #expect(grid.columnCount(for: 209, itemCount: 6) == 1)
        #expect(grid.columnCount(for: 210, itemCount: 6) == 2)
        #expect(grid.columnCount(for: 430, itemCount: 6) == 4)
    }

    @Test func capsColumnsAtTheNumberOfChildren() {
        #expect(grid.columnCount(for: 1_000, itemCount: 3) == 3)
        #expect(grid.columnCount(for: 1_000, itemCount: 0) == 0)
    }
}
