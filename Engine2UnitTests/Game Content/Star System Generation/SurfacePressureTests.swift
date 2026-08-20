import Testing
@testable import Engine2

nonisolated struct SurfacePressureTests {
    @Test func barConversionPreservesTheNamedUnit() {
        let bar = SurfacePressure(bars: 1)

        #expect(bar == .bar)
        #expect(bar.bars == 1)
    }
}
