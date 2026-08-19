import Testing
import simd

@testable import Engine2

nonisolated struct GravitySystemGeneratorTests {
    private let sourceGenerator = StarSystemGenerator(policy: .coreAccretionLiteV1)
    private let gravityGenerator = GravitySystemGenerator(modelVersion: .planarKeplerV1)

    @Test func sameSourceProducesExactlyEqualCompleteRailSystems() throws {
        let source = try sourceGenerator.generate(seed: StarSystemSeed(rawValue: 1))

        let first = try gravityGenerator.generate(from: source)
        let second = try gravityGenerator.generate(from: source)

        #expect(first == second)
        #expect(first.bodies == first.bodies.sorted(by: { $0.id < $1.id }))
        #expect(first.bodies.count == source.planets.reduce(0) { $0 + 1 + $1.moons.count })
        try first.validate()
    }

    @Test func versionOnePhaseAddressPinsBodyOrientationAndMeanAnomaly() {
        let seed = StarSystemSeed(rawValue: 0)
        let firstPlanetID = GeneratedBodyID.planet(formationIndex: 0)
        let secondPlanetID = GeneratedBodyID.planet(formationIndex: 1)

        let firstLongitudeOfPeriapsis = GravitySystemGenerator.phase(
            seed: seed,
            modelVersion: .planarKeplerV1,
            bodyID: firstPlanetID,
            domain: GravitySystemGenerator.periapsisDomain
        )
        let firstMeanAnomaly = GravitySystemGenerator.phase(
            seed: seed,
            modelVersion: .planarKeplerV1,
            bodyID: firstPlanetID,
            domain: GravitySystemGenerator.meanAnomalyDomain
        )
        let secondLongitudeOfPeriapsis = GravitySystemGenerator.phase(
            seed: seed,
            modelVersion: .planarKeplerV1,
            bodyID: secondPlanetID,
            domain: GravitySystemGenerator.periapsisDomain
        )
        let secondMeanAnomaly = GravitySystemGenerator.phase(
            seed: seed,
            modelVersion: .planarKeplerV1,
            bodyID: secondPlanetID,
            domain: GravitySystemGenerator.meanAnomalyDomain
        )

        #expect(firstLongitudeOfPeriapsis.bitPattern == 0x4007_B380_C112_C2EE)
        #expect(firstMeanAnomaly.bitPattern == 0x4012_226D_09A6_C401)
        #expect(secondLongitudeOfPeriapsis.bitPattern == 0x4006_718C_72AF_0AC5)
        #expect(secondMeanAnomaly.bitPattern == 0x4001_8BEB_CB16_C9C3)
    }

    @Test func projectionRetainsSelectedOrbitFactsAndComposesMoonStateWithItsParent() throws {
        let source = try sourceGenerator.generate(seed: StarSystemSeed(rawValue: 67))
        let sourcePlanet = try #require(source.planets.first)
        let sourceMoon = try #require(sourcePlanet.moons.first)

        let gravitySystem = try gravityGenerator.generate(from: source)
        let planet = try #require(gravitySystem.bodies.first(where: { $0.id == sourcePlanet.id }))
        let moon = try #require(gravitySystem.bodies.first(where: { $0.id == sourceMoon.id }))
        let ephemeris = try GravitySystemEphemeris(system: gravitySystem)
        let planetState = try #require(ephemeris.state(for: planet.id, at: gravitySystem.epoch))
        let moonState = try #require(ephemeris.state(for: moon.id, at: gravitySystem.epoch))
        let relativeMoonState = PlanarKeplerPropagationKernel().state(
            on: moon.rail,
            at: gravitySystem.epoch
        )

        #expect(planet.parentID == nil)
        #expect(moon.parentID == planet.id)
        #expect(planet.rail.semiMajorAxis == sourcePlanet.orbit.semiMajorAxis)
        #expect(planet.rail.eccentricity == sourcePlanet.orbit.eccentricity)
        #expect(moon.rail.semiMajorAxis == sourceMoon.orbit.semiMajorAxis)
        #expect(moon.rail.eccentricity == sourceMoon.orbit.eccentricity)
        #expect(
            vector(
                moonState.position.meters - planetState.position.meters,
                approximatelyEquals: relativeMoonState.position.meters
            )
        )
        #expect(
            vector(
                moonState.velocity.metersPerSecond - planetState.velocity.metersPerSecond,
                approximatelyEquals: relativeMoonState.velocity.metersPerSecond
            )
        )

        let allStates = ephemeris.states(at: gravitySystem.epoch)
        #expect(
            allStates.first(where: { $0.body.id == planet.id })?.state
                == planetState
        )
        #expect(
            allStates.first(where: { $0.body.id == moon.id })?.state
                == moonState
        )
    }

    @Test func validationRejectsPeriapsisContactWithStarOrParentBody() throws {
        let source = try sourceGenerator.generate(seed: StarSystemSeed(rawValue: 67))
        let sourcePlanet = try #require(source.planets.first)
        let sourceMoon = try #require(sourcePlanet.moons.first)
        let gravitySystem = try gravityGenerator.generate(from: source)
        let planet = try #require(gravitySystem.bodies.first(where: { $0.id == sourcePlanet.id }))
        let moon = try #require(gravitySystem.bodies.first(where: { $0.id == sourceMoon.id }))

        let stellarContactSystem = replacingRail(
            for: planet,
            in: gravitySystem,
            withPeriapsisAtCombinedRadiusOf: gravitySystem.starRadius
        )
        #expect(
            throws: GravitySystemGenerationError.periapsisIntersectsPrimary(
                body: planet.id,
                primaryBodyID: nil
            )
        ) {
            try stellarContactSystem.validate()
        }

        let parentContactSystem = replacingRail(
            for: moon,
            in: gravitySystem,
            withPeriapsisAtCombinedRadiusOf: planet.radius
        )
        #expect(
            throws: GravitySystemGenerationError.periapsisIntersectsPrimary(
                body: moon.id,
                primaryBodyID: planet.id
            )
        ) {
            try parentContactSystem.validate()
        }
    }

    private func replacingRail(
        for body: GravityRailBody,
        in system: GeneratedGravitySystem,
        withPeriapsisAtCombinedRadiusOf primaryRadius: AstronomicalDistance
    ) -> GeneratedGravitySystem {
        let replacement = GravityRailBody(
            id: body.id,
            parentID: body.parentID,
            mass: body.mass,
            radius: body.radius,
            rail: PlanarKeplerianRail(
                semiMajorAxis: AstronomicalDistance(
                    meters: primaryRadius.meters + body.radius.meters
                ),
                eccentricity: .circular,
                longitudeOfPeriapsisRadians: body.rail.longitudeOfPeriapsisRadians,
                meanAnomalyAtEpochRadians: body.rail.meanAnomalyAtEpochRadians,
                epoch: body.rail.epoch,
                gravitationalParameter: body.rail.gravitationalParameter
            )
        )
        return GeneratedGravitySystem(
            seed: system.seed,
            modelVersion: system.modelVersion,
            epoch: system.epoch,
            starMass: system.starMass,
            starRadius: system.starRadius,
            bodies: system.bodies.map { $0.id == body.id ? replacement : $0 }
        )
    }

    private func vector(
        _ first: SIMD2<Double>,
        approximatelyEquals second: SIMD2<Double>
    ) -> Bool {
        let difference = simd_length(first - second)
        let scale = max(simd_length(first), simd_length(second), 1)
        return difference <= scale * 1e-12
    }
}
