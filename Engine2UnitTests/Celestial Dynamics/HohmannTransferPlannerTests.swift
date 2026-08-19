import Testing
import simd

@testable import Engine2

nonisolated struct HohmannTransferPlannerTests {
    @Test func earthMarsReferencePinsWindowTransferAndKernelEndpoints() throws {
        let system = earthMarsReferenceSystem()
        let planner = try HohmannTransferPlanner(system: system)

        let plan = try planner.plan(
            from: .planet(formationIndex: 0),
            to: .planet(formationIndex: 1),
            noEarlierThan: .zero
        )
        let kernel = PlanarKeplerPropagationKernel()
        let departure = kernel.state(on: plan.transferRail, at: plan.departureEpoch)
        let arrival = kernel.state(on: plan.transferRail, at: plan.arrivalEpoch)
        let samples = kernel.samples(
            on: plan.transferRail,
            from: plan.departureEpoch,
            through: plan.arrivalEpoch,
            sampleCount: 65
        )

        #expect(approximatelyEqual(plan.nextWindowWait.seconds, 32_300_552.005786635))
        #expect(approximatelyEqual(plan.departureEpoch.secondsSinceReferenceEpoch, 32_300_552.005786635))
        #expect(approximatelyEqual(plan.arrivalEpoch.secondsSinceReferenceEpoch, 54_666_215.41272326))
        #expect(approximatelyEqual(plan.transferDuration.seconds, 22_365_663.40693662))
        #expect(approximatelyEqual(plan.requiredPhaseAngleRadians, 0.7739517891620693))
        #expect(approximatelyEqual(plan.departureDeltaVMetersPerSecond, 2_944.733779132246))
        #expect(approximatelyEqual(plan.arrivalDeltaVMetersPerSecond, 2_648.935279657868))
        #expect(approximatelyEqual(plan.totalDeltaVMetersPerSecond, 5_593.669058790114))
        #expect(plan.departureEpoch == CelestialEpoch.zero.advanced(by: plan.nextWindowWait))
        #expect(plan.arrivalEpoch == plan.departureEpoch.advanced(by: plan.transferDuration))
        #expect(
            approximatelyEqual(
                simd_length(departure.position.meters),
                plan.sourceReferenceRadius.meters
            )
        )
        #expect(
            approximatelyEqual(
                simd_length(arrival.position.meters),
                plan.destinationReferenceRadius.meters
            )
        )
        #expect(samples.first?.state == departure)
        #expect(samples.last?.state == arrival)
    }

    private func earthMarsReferenceSystem() -> GeneratedGravitySystem {
        let epoch = CelestialEpoch.zero
        let seed = StarSystemSeed(rawValue: 0)
        let starMass = AstronomicalMass.sun
        let earthID = GeneratedBodyID.planet(formationIndex: 0)
        let marsID = GeneratedBodyID.planet(formationIndex: 1)
        let earth = GravityRailBody(
            id: earthID,
            parentID: nil,
            mass: .earth,
            radius: .earthRadius,
            rail: PlanarKeplerianRail(
                semiMajorAxis: .astronomicalUnit,
                eccentricity: .circular,
                longitudeOfPeriapsisRadians: GravitySystemGenerator.phase(
                    seed: seed,
                    modelVersion: .planarKeplerV1,
                    bodyID: earthID,
                    domain: GravitySystemGenerator.periapsisDomain
                ),
                meanAnomalyAtEpochRadians: GravitySystemGenerator.phase(
                    seed: seed,
                    modelVersion: .planarKeplerV1,
                    bodyID: earthID,
                    domain: GravitySystemGenerator.meanAnomalyDomain
                ),
                epoch: epoch,
                gravitationalParameter: GravitationalParameter(
                    primaryMass: starMass,
                    orbitingMass: .earth
                )
            )
        )
        let marsMass = AstronomicalMass(earthMasses: 0.1074)
        let mars = GravityRailBody(
            id: marsID,
            parentID: nil,
            mass: marsMass,
            radius: AstronomicalDistance(earthRadii: 0.532),
            rail: PlanarKeplerianRail(
                semiMajorAxis: AstronomicalDistance(astronomicalUnits: 1.523679),
                eccentricity: .circular,
                longitudeOfPeriapsisRadians: GravitySystemGenerator.phase(
                    seed: seed,
                    modelVersion: .planarKeplerV1,
                    bodyID: marsID,
                    domain: GravitySystemGenerator.periapsisDomain
                ),
                meanAnomalyAtEpochRadians: GravitySystemGenerator.phase(
                    seed: seed,
                    modelVersion: .planarKeplerV1,
                    bodyID: marsID,
                    domain: GravitySystemGenerator.meanAnomalyDomain
                ),
                epoch: epoch,
                gravitationalParameter: GravitationalParameter(
                    primaryMass: starMass,
                    orbitingMass: marsMass
                )
            )
        )
        return GeneratedGravitySystem(
            seed: seed,
            modelVersion: .planarKeplerV1,
            epoch: epoch,
            starMass: starMass,
            starRadius: .solarRadius,
            bodies: [earth, mars]
        )
    }

    private func approximatelyEqual(_ first: Double, _ second: Double) -> Bool {
        let scale = max(abs(first), abs(second), 1)
        return abs(first - second) <= scale * 1e-11
    }
}
