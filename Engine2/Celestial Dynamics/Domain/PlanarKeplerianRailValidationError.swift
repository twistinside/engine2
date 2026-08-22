/// Rejects a planar rail whose stored or derived values cannot be propagated safely.
nonisolated enum PlanarKeplerianRailValidationError: Error, Equatable, Sendable {
    case invalidSemiMajorAxis
    case invalidEccentricity
    case invalidLongitudeOfPeriapsis
    case invalidMeanAnomalyAtEpoch
    case invalidEpoch
    case invalidGravitationalParameter
    case unrepresentableMeanMotion
    case unrepresentableOrbitalPeriod

    var message: String {
        switch self {
        case .invalidSemiMajorAxis:
            "A planar Keplerian rail requires a positive finite semi-major axis."
        case .invalidEccentricity:
            "A planar Keplerian rail requires a finite eccentricity in 0..<1."
        case .invalidLongitudeOfPeriapsis:
            "Longitude of periapsis must be finite."
        case .invalidMeanAnomalyAtEpoch:
            "Mean anomaly must be finite."
        case .invalidEpoch:
            "A planar Keplerian rail requires a finite nonnegative epoch."
        case .invalidGravitationalParameter:
            "A planar Keplerian rail requires a positive finite gravitational parameter."
        case .unrepresentableMeanMotion:
            "The rail's semi-major axis and gravitational parameter must produce finite positive mean motion."
        case .unrepresentableOrbitalPeriod:
            "The rail's mean motion must produce a finite positive orbital period."
        }
    }
}
