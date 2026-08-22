import Darwin
import simd

/// Evaluates and samples bound prograde planar Keplerian rails.
///
/// The kernel uses one fixed-count bisection solve for Kepler's equation.
/// Current rail consumers request states through this type. Future gameplay
/// execution must use the same implementation so prediction and presentation
/// cannot diverge.
nonisolated struct PlanarKeplerPropagationKernel: Sendable {
    static let eccentricAnomalyIterationCount = 64
    static let maximumTrajectorySampleCount = 4_097

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

    /// Samples one rail at evenly spaced absolute epochs, including both endpoints.
    func samples(
        on rail: PlanarKeplerianRail,
        from startEpoch: CelestialEpoch,
        through endEpoch: CelestialEpoch,
        sampleCount: Int
    ) -> [PlanarTrajectorySample] {
        precondition(
            (2...Self.maximumTrajectorySampleCount).contains(sampleCount),
            "Rail sampling requires 2 through \(Self.maximumTrajectorySampleCount) samples."
        )
        precondition(startEpoch <= endEpoch, "Rail sampling epochs must be ordered.")

        let intervalSeconds = endEpoch.secondsSinceReferenceEpoch
            - startEpoch.secondsSinceReferenceEpoch
        let denominator = Double(sampleCount - 1)
        return (0..<sampleCount).map { index in
            let epoch: CelestialEpoch
            if index == 0 {
                epoch = startEpoch
            } else if index == sampleCount - 1 {
                epoch = endEpoch
            } else {
                let fraction = Double(index) / denominator
                epoch = CelestialEpoch(
                    secondsSinceReferenceEpoch:
                        startEpoch.secondsSinceReferenceEpoch + intervalSeconds * fraction
                )
            }
            return PlanarTrajectorySample(
                epoch: epoch,
                state: state(on: rail, at: epoch)
            )
        }
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
