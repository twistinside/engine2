import Darwin
import simd

/// Evaluates bound prograde planar Keplerian rails.
///
/// The kernel uses one fixed-count bisection solve for Kepler's equation.
/// Generated-system tools and prescribed Simulation rails share this evaluator,
/// so their prediction, presentation, and execution states cannot diverge.
/// Spacecraft maneuvers and authority transitions remain unsupported.
nonisolated struct PlanarKeplerPropagationKernel: Sendable {
    static let eccentricAnomalyIterationCount = 64

    /// Evaluates one rail at an absolute celestial epoch.
    func state(
        on rail: PlanarKeplerianRail,
        at epoch: CelestialEpoch
    ) -> PlanarStateVector {
        let semiMajorAxisMeters = rail.semiMajorAxis.meters
        let meanMotionRadiansPerSecond = rail.meanMotionRadiansPerSecond
        let elapsedSeconds = epoch.secondsSinceReferenceEpoch
            - rail.epoch.secondsSinceReferenceEpoch
        let reducedElapsedSeconds = elapsedSeconds.truncatingRemainder(
            dividingBy: rail.orbitalPeriod.seconds
        )
        let meanAnomaly = PlanarKeplerianRail.canonicalAngle(
            rail.meanAnomalyAtEpochRadians
                + meanMotionRadiansPerSecond * reducedElapsedSeconds
        )
        let eccentricAnomaly = solveEccentricAnomaly(
            meanAnomaly: meanAnomaly,
            eccentricity: rail.eccentricity.rawValue
        )
        return state(
            semiMajorAxisMeters: semiMajorAxisMeters,
            eccentricity: rail.eccentricity.rawValue,
            eccentricAnomaly: eccentricAnomaly,
            meanMotionRadiansPerSecond: meanMotionRadiansPerSecond,
            longitudeOfPeriapsisRadians: rail.longitudeOfPeriapsisRadians
        )
    }

    private func solveEccentricAnomaly(
        meanAnomaly: Double,
        eccentricity: Double
    ) -> Double {
        precondition((0..<1).contains(eccentricity), "The propagation kernel requires a bound orbit.")
        guard meanAnomaly != 0 else {
            return 0
        }

        var lowerBound = 0.0
        var upperBound = 2 * Double.pi
        for _ in 0..<Self.eccentricAnomalyIterationCount {
            let candidate = (lowerBound + upperBound) / 2
            let candidateMeanAnomaly = candidate - eccentricity * sin(candidate)
            if candidateMeanAnomaly < meanAnomaly {
                lowerBound = candidate
            } else {
                upperBound = candidate
            }
        }
        return (lowerBound + upperBound) / 2
    }

    private func state(
        semiMajorAxisMeters: Double,
        eccentricity: Double,
        eccentricAnomaly: Double,
        meanMotionRadiansPerSecond: Double,
        longitudeOfPeriapsisRadians: Double
    ) -> PlanarStateVector {
        let cosineEccentricAnomaly = cos(eccentricAnomaly)
        let sineEccentricAnomaly = sin(eccentricAnomaly)
        let eccentricityComplement = (1 - eccentricity * eccentricity).squareRoot()
        let velocityDenominator = 1 - eccentricity * cosineEccentricAnomaly
        let orbitalPosition = SIMD2<Double>(
            semiMajorAxisMeters * (cosineEccentricAnomaly - eccentricity),
            semiMajorAxisMeters * eccentricityComplement * sineEccentricAnomaly
        )
        let orbitalVelocity = SIMD2<Double>(
            -semiMajorAxisMeters * meanMotionRadiansPerSecond
                * sineEccentricAnomaly / velocityDenominator,
            semiMajorAxisMeters * meanMotionRadiansPerSecond
                * eccentricityComplement * cosineEccentricAnomaly / velocityDenominator
        )
        let cosinePeriapsis = cos(longitudeOfPeriapsisRadians)
        let sinePeriapsis = sin(longitudeOfPeriapsisRadians)
        let rotation = simd_double2x2(
            columns: (
                SIMD2<Double>(cosinePeriapsis, sinePeriapsis),
                SIMD2<Double>(-sinePeriapsis, cosinePeriapsis)
            )
        )
        return PlanarStateVector(
            position: PlanarPosition(meters: rotation * orbitalPosition),
            velocity: PlanarVelocity(metersPerSecond: rotation * orbitalVelocity)
        )
    }
}
