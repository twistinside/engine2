import Testing
import simd

@testable import Engine2

nonisolated struct PlanarKeplerPropagationKernelTests {
    private let kernel = PlanarKeplerPropagationKernel()

    @Test func circularRailClosesAndPassesPinnedQuarterOrbitStates() {
        let rail = PlanarKeplerianRail(
            semiMajorAxis: .astronomicalUnit,
            eccentricity: .circular,
            longitudeOfPeriapsisRadians: 0,
            meanAnomalyAtEpochRadians: 0,
            epoch: .zero,
            gravitationalParameter: GravitationalParameter(
                primaryMass: .sun,
                orbitingMass: .zero
            )
        )
        let period = rail.orbitalPeriod.seconds
        let circularSpeed = (
            rail.gravitationalParameter.cubicMetersPerSecondSquared
                / rail.semiMajorAxis.meters
        ).squareRoot()

        let initial = kernel.state(on: rail, at: .zero)
        let quarter = kernel.state(
            on: rail,
            at: CelestialEpoch(secondsSinceReferenceEpoch: period / 4)
        )
        let completed = kernel.state(
            on: rail,
            at: CelestialEpoch(secondsSinceReferenceEpoch: period)
        )

        #expect(vector(initial.position.meters, approximatelyEquals: SIMD2<Double>(rail.semiMajorAxis.meters, 0)))
        #expect(vector(initial.velocity.metersPerSecond, approximatelyEquals: SIMD2<Double>(0, circularSpeed)))
        #expect(vector(quarter.position.meters, approximatelyEquals: SIMD2<Double>(0, rail.semiMajorAxis.meters)))
        #expect(vector(quarter.velocity.metersPerSecond, approximatelyEquals: SIMD2<Double>(-circularSpeed, 0)))
        #expect(vector(completed.position.meters, approximatelyEquals: initial.position.meters))
        #expect(vector(completed.velocity.metersPerSecond, approximatelyEquals: initial.velocity.metersPerSecond))
    }

    @Test func eccentricRailReachesItsApsidesAndSamplingUsesTheSameEvaluator() {
        let semiMajorAxis = AstronomicalDistance(astronomicalUnits: 2)
        let eccentricity = OrbitalEccentricity(rawValue: 0.25)
        let rail = PlanarKeplerianRail(
            semiMajorAxis: semiMajorAxis,
            eccentricity: eccentricity,
            longitudeOfPeriapsisRadians: 0,
            meanAnomalyAtEpochRadians: 0,
            epoch: .zero,
            gravitationalParameter: GravitationalParameter(
                primaryMass: .sun,
                orbitingMass: .zero
            )
        )
        let apoapsisEpoch = CelestialEpoch(
            secondsSinceReferenceEpoch: rail.orbitalPeriod.seconds / 2
        )

        let periapsis = kernel.state(on: rail, at: .zero)
        let apoapsis = kernel.state(on: rail, at: apoapsisEpoch)
        let samples = kernel.samples(
            on: rail,
            from: .zero,
            through: apoapsisEpoch,
            sampleCount: 9
        )

        #expect(
            approximatelyEqual(
                simd_length(periapsis.position.meters),
                semiMajorAxis.meters * (1 - eccentricity.rawValue)
            )
        )
        #expect(
            approximatelyEqual(
                simd_length(apoapsis.position.meters),
                semiMajorAxis.meters * (1 + eccentricity.rawValue)
            )
        )
        #expect(samples.first == PlanarTrajectorySample(epoch: .zero, state: periapsis))
        #expect(samples.last == PlanarTrajectorySample(epoch: apoapsisEpoch, state: apoapsis))
    }

    private func vector(
        _ first: SIMD2<Double>,
        approximatelyEquals second: SIMD2<Double>
    ) -> Bool {
        let difference = simd_length(first - second)
        let scale = max(simd_length(first), simd_length(second), 1)
        return difference <= scale * 1e-12
    }

    private func approximatelyEqual(_ first: Double, _ second: Double) -> Bool {
        let scale = max(abs(first), abs(second), 1)
        return abs(first - second) <= scale * 1e-11
    }
}
