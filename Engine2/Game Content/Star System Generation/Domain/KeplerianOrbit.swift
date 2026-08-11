/// Reduced bound-orbit description used by the baseline generator.
///
/// Longitude, argument of periapsis, and epoch anomaly are deferred because the
/// first model generates architecture and environment rather than live orbital
/// phase. Inclination is expressed in degrees relative to the system plane.
nonisolated struct KeplerianOrbit: Codable, Equatable, Sendable {
    let semiMajorAxis: AstronomicalDistance
    let eccentricity: OrbitalEccentricity
    let inclinationDegrees: Double

    init(
        semiMajorAxis: AstronomicalDistance,
        eccentricity: OrbitalEccentricity,
        inclinationDegrees: Double
    ) {
        precondition(semiMajorAxis.meters > 0, "A bound orbit requires a positive semi-major axis.")
        precondition(
            inclinationDegrees.isFinite && inclinationDegrees >= 0 && inclinationDegrees <= 180,
            "Orbital inclination must be finite in 0...180 degrees."
        )
        self.semiMajorAxis = semiMajorAxis
        self.eccentricity = eccentricity
        self.inclinationDegrees = inclinationDegrees
    }
}
