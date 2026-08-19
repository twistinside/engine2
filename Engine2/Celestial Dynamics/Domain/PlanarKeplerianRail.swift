/// Complete bound prograde orbit in one shared two-dimensional plane.
///
/// The rail stores orientation and phase at an explicit epoch, which lets one
/// propagation kernel reproduce position and velocity without mutable history.
/// Angles are canonical radians in `0..<2π`.
nonisolated struct PlanarKeplerianRail: Codable, Equatable, Sendable {
    let semiMajorAxis: AstronomicalDistance
    let eccentricity: OrbitalEccentricity
    let longitudeOfPeriapsisRadians: Double
    let meanAnomalyAtEpochRadians: Double
    let epoch: CelestialEpoch
    let gravitationalParameter: GravitationalParameter

    var meanMotionRadiansPerSecond: Double {
        let axis = semiMajorAxis.meters
        return (
            gravitationalParameter.cubicMetersPerSecondSquared / axis
        ).squareRoot() / axis
    }

    var orbitalPeriod: AstronomicalDuration {
        return AstronomicalDuration(
            seconds: 2 * Double.pi / meanMotionRadiansPerSecond
        )
    }

    init(
        semiMajorAxis: AstronomicalDistance,
        eccentricity: OrbitalEccentricity,
        longitudeOfPeriapsisRadians: Double,
        meanAnomalyAtEpochRadians: Double,
        epoch: CelestialEpoch,
        gravitationalParameter: GravitationalParameter
    ) {
        precondition(semiMajorAxis.meters > 0, "A planar Keplerian rail requires a positive semi-major axis.")
        precondition(longitudeOfPeriapsisRadians.isFinite, "Longitude of periapsis must be finite.")
        precondition(meanAnomalyAtEpochRadians.isFinite, "Mean anomaly must be finite.")
        self.semiMajorAxis = semiMajorAxis
        self.eccentricity = eccentricity
        self.longitudeOfPeriapsisRadians = Self.canonicalAngle(longitudeOfPeriapsisRadians)
        self.meanAnomalyAtEpochRadians = Self.canonicalAngle(meanAnomalyAtEpochRadians)
        self.epoch = epoch
        self.gravitationalParameter = gravitationalParameter
    }

    /// Returns one finite angle in the canonical `0..<2π` interval.
    static func canonicalAngle(_ radians: Double) -> Double {
        precondition(radians.isFinite, "An orbital angle must be finite.")
        let remainder = radians.truncatingRemainder(dividingBy: 2 * Double.pi)
        let canonical = remainder < 0 ? remainder + 2 * Double.pi : remainder
        return canonical == 0 ? 0 : canonical
    }
}
