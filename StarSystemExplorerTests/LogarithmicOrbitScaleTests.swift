import Testing

@testable import StarSystemExplorer

nonisolated struct LogarithmicOrbitScaleTests {
    private let scale = LogarithmicOrbitScale(lowerBound: 0, upperBound: 100)

    @Test func mapsBoundsAndClampsOutsideValues() {
        #expect(scale.position(for: -1) == 0)
        #expect(scale.position(for: 0) == 0)
        #expect(scale.position(for: 100) == 1)
        #expect(scale.position(for: 1_000) == 1)
    }

    @Test func inverseValuesMapToEqualVisualIntervals() {
        for expectedPosition in [0.0, 0.25, 0.5, 0.75, 1] {
            let value = scale.value(at: expectedPosition)
            #expect(abs(scale.position(for: value) - expectedPosition) < 1e-12)
        }
    }

    @Test func remainsFiniteAndMonotonicAcrossTheRange() {
        let values = [0, 0.03, 0.1, 1, 12, 100]
        let positions = values.map(scale.position(for:))
        let allPositionsAreFinite = positions.allSatisfy(\.isFinite)
        let positionsAreMonotonic = zip(positions, positions.dropFirst()).allSatisfy { pair in
            pair.0 < pair.1
        }

        #expect(allPositionsAreFinite)
        #expect(positionsAreMonotonic)
    }
}
