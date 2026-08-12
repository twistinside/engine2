import Testing

@testable import StarSystemExplorer

nonisolated struct StarSystemOrbitScaleTests {
    private let range = 0.0...100.0

    @Test func linearScaleMapsEqualDistancesToEqualIntervals() {
        #expect(StarSystemOrbitScale.linear.position(for: 0, in: range) == 0)
        #expect(abs(StarSystemOrbitScale.linear.position(for: 25, in: range) - 0.25) < 1e-12)
        #expect(abs(StarSystemOrbitScale.linear.position(for: 50, in: range) - 0.5) < 1e-12)
        #expect(StarSystemOrbitScale.linear.position(for: 100, in: range) == 1)
    }

    @Test func bothScaleModesClampValuesToTheVisibleTrack() {
        for scale in StarSystemOrbitScale.allCases {
            #expect(scale.position(for: -1, in: range) == 0)
            #expect(scale.position(for: 1_000, in: range) == 1)
        }
    }

    @Test func linearTicksUseEqualVisualIntervalsAcrossTheVisibleRange() {
        let ticks = StarSystemOrbitScale.linear.tickValues(in: range)
        let positions = ticks.map { StarSystemOrbitScale.linear.position(for: $0, in: range) }

        #expect(ticks.count == 5)
        #expect(positions.elementsEqual([0, 0.25, 0.5, 0.75, 1]) { abs($0 - $1) < 1e-12 })
    }

    @Test func logarithmicTicksUseEqualVisualIntervalsAcrossTheVisibleRange() {
        let ticks = StarSystemOrbitScale.logarithmic.tickValues(in: range)
        let positions = ticks.map { StarSystemOrbitScale.logarithmic.position(for: $0, in: range) }

        #expect(ticks.count == 5)
        #expect(positions.elementsEqual([0, 0.25, 0.5, 0.75, 1]) { abs($0 - $1) < 1e-12 })
    }
}
