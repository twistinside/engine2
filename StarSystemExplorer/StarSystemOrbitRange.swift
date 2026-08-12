/// Resolves the visible orbital domain from the system's planets.
///
/// The range starts at the star and adds proportional headroom beyond the
/// outermost apoapsis. Systems without planets extend from the star to the
/// supplied disk's outer edge.
nonisolated struct StarSystemOrbitRange: Equatable, Sendable {
    static let defaultPaddingFraction = 0.1

    let visibleRange: ClosedRange<Double>
    let usesFallback: Bool

    init(
        orbits: [KeplerianOrbit],
        fallback: ClosedRange<Double>,
        paddingFraction: Double = Self.defaultPaddingFraction
    ) {
        precondition(
            fallback.lowerBound.isFinite && fallback.lowerBound >= 0,
            "The fallback orbital range must start at a finite nonnegative distance."
        )
        precondition(
            fallback.upperBound.isFinite && fallback.upperBound > fallback.lowerBound,
            "The fallback orbital range must end beyond its lower bound."
        )
        precondition(
            paddingFraction.isFinite && paddingFraction > 0 && paddingFraction < 1,
            "Orbital range padding must be finite, greater than zero, and less than one."
        )

        guard !orbits.isEmpty else {
            visibleRange = 0...fallback.upperBound
            usesFallback = true
            return
        }

        let maximumApoapsis = orbits.reduce(0.0) { currentMaximum, orbit in
            let semiMajorAxis = orbit.semiMajorAxis.astronomicalUnits
            return max(currentMaximum, semiMajorAxis * (1 + orbit.eccentricity.rawValue))
        }

        visibleRange = 0...maximumApoapsis * (1 + paddingFraction)
        usesFallback = false
    }
}
