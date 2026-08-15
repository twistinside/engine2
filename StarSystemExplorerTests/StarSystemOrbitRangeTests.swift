import Testing

@testable import StarSystemExplorer

nonisolated struct StarSystemOrbitRangeTests {
    private let fallback = 0.03...150.0

    @Test func rangeStartsAtZeroAndPadsTheOutermostApoapsis() {
        let range = StarSystemOrbitRange(
            orbits: [
                orbit(semiMajorAxis: 2, eccentricity: 0.25),
                orbit(semiMajorAxis: 10, eccentricity: 0.2),
            ],
            fallback: fallback
        )

        #expect(range.visibleRange.lowerBound == 0)
        #expect(abs(range.visibleRange.upperBound - 13.2) < 1e-12)
        #expect(!range.usesFallback)
    }

    @Test func circularOrbitReceivesOuterHeadroom() {
        let range = StarSystemOrbitRange(
            orbits: [orbit(semiMajorAxis: 5)],
            fallback: fallback
        )

        #expect(range.visibleRange.lowerBound == 0)
        #expect(abs(range.visibleRange.upperBound - 5.5) < 1e-12)
    }

    @Test func systemWithoutPlanetsUsesDiskFallback() {
        let range = StarSystemOrbitRange(orbits: [], fallback: fallback)

        #expect(range.visibleRange == 0...fallback.upperBound)
        #expect(range.usesFallback)
    }

    private func orbit(semiMajorAxis: Double, eccentricity: Double = 0) -> KeplerianOrbit {
        KeplerianOrbit(
            semiMajorAxis: AstronomicalDistance(astronomicalUnits: semiMajorAxis),
            eccentricity: OrbitalEccentricity(rawValue: eccentricity),
            inclinationDegrees: 0
        )
    }
}
