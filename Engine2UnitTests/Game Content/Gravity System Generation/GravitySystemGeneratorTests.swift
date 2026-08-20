import Foundation
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

    @Test func completeGeneratedSystemRoundTripsThroughJSONAndRemainsValid() throws {
        let source = try sourceGenerator.generate(seed: StarSystemSeed(rawValue: 67))
        let original = try gravityGenerator.generate(from: source)

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GeneratedGravitySystem.self, from: encoded)

        #expect(decoded == original)
        try decoded.validate()
    }

    @Test func versionOnePhaseAddressPinsBodyOrientationAndMeanAnomaly() {
        let seed = StarSystemSeed(rawValue: 0)
        let firstPlanetID = GeneratedBodyID.planet(formationIndex: 0)
        let secondPlanetID = GeneratedBodyID.planet(formationIndex: 1)

        let firstLongitudeOfPeriapsis = GravitySystemGenerator.phase(
            seed: seed,
            modelVersion: .planarKeplerV1,
            bodyID: firstPlanetID,
            domain: .longitudeOfPeriapsis
        )
        let firstMeanAnomaly = GravitySystemGenerator.phase(
            seed: seed,
            modelVersion: .planarKeplerV1,
            bodyID: firstPlanetID,
            domain: .meanAnomalyAtEpoch
        )
        let secondLongitudeOfPeriapsis = GravitySystemGenerator.phase(
            seed: seed,
            modelVersion: .planarKeplerV1,
            bodyID: secondPlanetID,
            domain: .longitudeOfPeriapsis
        )
        let secondMeanAnomaly = GravitySystemGenerator.phase(
            seed: seed,
            modelVersion: .planarKeplerV1,
            bodyID: secondPlanetID,
            domain: .meanAnomalyAtEpoch
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
        let allStates = ephemeris.evaluatedBodyStates(at: gravitySystem.epoch)
        let planetState = try #require(
            allStates.first(where: { $0.body.id == planet.id })?.state
        )
        let moonState = try #require(
            allStates.first(where: { $0.body.id == moon.id })?.state
        )
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

        #expect(
            allStates.map(\.body.id) == gravitySystem.bodies.map(\.id)
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

    @Test func validationRejectsUnorderedBodies() throws {
        let source = try sourceGenerator.generate(seed: StarSystemSeed(rawValue: 67))
        let gravitySystem = try gravityGenerator.generate(from: source)

        let unorderedSystem = replacingBodies(
            Array(gravitySystem.bodies.reversed()),
            in: gravitySystem
        )
        #expect(throws: GravitySystemGenerationError.bodiesNotOrdered) {
            try unorderedSystem.validate()
        }
    }

    @Test func validationRejectsDuplicateBodyIdentity() throws {
        let source = try sourceGenerator.generate(seed: StarSystemSeed(rawValue: 67))
        let gravitySystem = try gravityGenerator.generate(from: source)
        let firstBody = try #require(gravitySystem.bodies.first)

        let duplicateBodies = (gravitySystem.bodies + [firstBody]).sorted { $0.id < $1.id }
        let duplicateSystem = replacingBodies(duplicateBodies, in: gravitySystem)
        #expect(throws: GravitySystemGenerationError.duplicateBodyID(firstBody.id)) {
            try duplicateSystem.validate()
        }
    }

    @Test func validationRejectsMissingParent() throws {
        let source = try sourceGenerator.generate(seed: StarSystemSeed(rawValue: 67))
        let sourcePlanet = try #require(source.planets.first)
        let sourceMoon = try #require(sourcePlanet.moons.first)
        let gravitySystem = try gravityGenerator.generate(from: source)
        let planet = try #require(gravitySystem.bodies.first(where: { $0.id == sourcePlanet.id }))
        let moon = try #require(gravitySystem.bodies.first(where: { $0.id == sourceMoon.id }))

        let missingParentSystem = replacingBodies(
            gravitySystem.bodies.filter { $0.id != planet.id },
            in: gravitySystem
        )
        #expect(
            throws: GravitySystemGenerationError.missingParent(
                body: moon.id,
                parent: planet.id
            )
        ) {
            try missingParentSystem.validate()
        }
    }

    @Test func validationRejectsCorruptedPhase() throws {
        let source = try sourceGenerator.generate(seed: StarSystemSeed(rawValue: 67))
        let sourcePlanet = try #require(source.planets.first)
        let gravitySystem = try gravityGenerator.generate(from: source)
        let planet = try #require(gravitySystem.bodies.first(where: { $0.id == sourcePlanet.id }))

        let corruptedPhaseBody = GravityRailBody(
            id: planet.id,
            parentID: planet.parentID,
            mass: planet.mass,
            radius: planet.radius,
            rail: PlanarKeplerianRail(
                semiMajorAxis: planet.rail.semiMajorAxis,
                eccentricity: planet.rail.eccentricity,
                longitudeOfPeriapsisRadians: planet.rail.longitudeOfPeriapsisRadians + 0.25,
                meanAnomalyAtEpochRadians: planet.rail.meanAnomalyAtEpochRadians,
                epoch: planet.rail.epoch,
                gravitationalParameter: planet.rail.gravitationalParameter
            )
        )
        let corruptedPhaseSystem = replacingBody(
            corruptedPhaseBody,
            in: gravitySystem
        )
        #expect(throws: GravitySystemGenerationError.inconsistentPhase(planet.id)) {
            try corruptedPhaseSystem.validate()
        }
    }

    @Test func validationRejectsStarWhoseGravitationalParameterUnderflows() {
        let system = GeneratedGravitySystem(
            seed: StarSystemSeed(rawValue: 0),
            modelVersion: .planarKeplerV1,
            epoch: .zero,
            starMass: AstronomicalMass(kilograms: .leastNonzeroMagnitude),
            starRadius: .solarRadius,
            bodies: []
        )

        #expect(throws: GravitySystemGenerationError.invalidStar) {
            try system.validate()
        }
    }

    @Test func validationRejectsBodyWhoseStandaloneGravitationalParameterUnderflows() {
        let bodyID = GeneratedBodyID.planet(formationIndex: 0)
        let starMass = AstronomicalMass.sun
        let bodyMass = AstronomicalMass(kilograms: .leastNonzeroMagnitude)
        let system = onePlanetSystem(
            starMass: starMass,
            bodyMass: bodyMass,
            railParameter: GravitationalParameter(
                primaryMass: starMass,
                orbitingMass: bodyMass
            )
        )

        #expect(throws: GravitySystemGenerationError.invalidBody(bodyID)) {
            try system.validate()
        }
    }

    @Test func validationRejectsMismatchedSmallGravitationalParameterByRelativeTolerance() {
        let bodyID = GeneratedBodyID.planet(formationIndex: 0)
        let starMass = AstronomicalMass(kilograms: 1)
        let bodyMass = AstronomicalMass(kilograms: 1)
        let expectedParameter = GravitationalParameter
            .newtonianGravitationalConstantCubicMetersPerKilogramSecondSquared
            * (starMass.kilograms + bodyMass.kilograms)
        let system = onePlanetSystem(
            starMass: starMass,
            bodyMass: bodyMass,
            railParameter: GravitationalParameter(
                cubicMetersPerSecondSquared: expectedParameter + 5e-13
            )
        )

        #expect(throws: GravitySystemGenerationError.inconsistentGravitationalParameter(bodyID)) {
            try system.validate()
        }
    }

    @Test func versionOneCompleteProjectionFingerprintsRemainStable() throws {
        let seeds = [
            StarSystemSeed(rawValue: 1),
            StarSystemSeed(rawValue: 17),
            StarSystemSeed(rawValue: 0xC0FFEE)
        ]
        let fingerprints = try seeds.map { seed in
            let sourceSystem = try sourceGenerator.generate(seed: seed)
            return gravitySystemFingerprint(
                try gravityGenerator.generate(from: sourceSystem)
            )
        }

        #expect(fingerprints == [
            0x7885_BA0D_2F9A_9D11,
            0xA1DC_1949_C36B_7038,
            0x688E_46F3_CBEE_710E
        ])
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
        return replacingBody(
            replacement,
            in: system
        )
    }

    private func replacingBody(
        _ replacement: GravityRailBody,
        in system: GeneratedGravitySystem
    ) -> GeneratedGravitySystem {
        replacingBodies(
            system.bodies.map { $0.id == replacement.id ? replacement : $0 },
            in: system
        )
    }

    private func replacingBodies(
        _ bodies: [GravityRailBody],
        in system: GeneratedGravitySystem
    ) -> GeneratedGravitySystem {
        GeneratedGravitySystem(
            seed: system.seed,
            modelVersion: system.modelVersion,
            epoch: system.epoch,
            starMass: system.starMass,
            starRadius: system.starRadius,
            bodies: bodies
        )
    }

    private func onePlanetSystem(
        starMass: AstronomicalMass,
        bodyMass: AstronomicalMass,
        railParameter: GravitationalParameter
    ) -> GeneratedGravitySystem {
        let seed = StarSystemSeed(rawValue: 0)
        let bodyID = GeneratedBodyID.planet(formationIndex: 0)
        let body = GravityRailBody(
            id: bodyID,
            parentID: nil,
            mass: bodyMass,
            radius: AstronomicalDistance(meters: 0.1),
            rail: PlanarKeplerianRail(
                semiMajorAxis: AstronomicalDistance(meters: 1),
                eccentricity: .circular,
                longitudeOfPeriapsisRadians: GravitySystemGenerator.phase(
                    seed: seed,
                    modelVersion: .planarKeplerV1,
                    bodyID: bodyID,
                    domain: .longitudeOfPeriapsis
                ),
                meanAnomalyAtEpochRadians: GravitySystemGenerator.phase(
                    seed: seed,
                    modelVersion: .planarKeplerV1,
                    bodyID: bodyID,
                    domain: .meanAnomalyAtEpoch
                ),
                epoch: .zero,
                gravitationalParameter: railParameter
            )
        )
        return GeneratedGravitySystem(
            seed: seed,
            modelVersion: .planarKeplerV1,
            epoch: .zero,
            starMass: starMass,
            starRadius: AstronomicalDistance(meters: 0.1),
            bodies: [body]
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

    private func gravitySystemFingerprint(_ system: GeneratedGravitySystem) -> UInt64 {
        var fingerprint: UInt64 = 0xCBF2_9CE4_8422_2325
        mix(system.seed.rawValue, into: &fingerprint)
        mix(UInt64(system.modelVersion.rawValue), into: &fingerprint)
        mix(system.epoch.secondsSinceReferenceEpoch.bitPattern, into: &fingerprint)
        mix(system.starMass.kilograms.bitPattern, into: &fingerprint)
        mix(system.starRadius.meters.bitPattern, into: &fingerprint)
        mix(UInt64(system.bodies.count), into: &fingerprint)

        for body in system.bodies {
            mix(body.id.rawValue, into: &fingerprint)
            if let parentID = body.parentID {
                mix(1, into: &fingerprint)
                mix(parentID.rawValue, into: &fingerprint)
            } else {
                mix(0, into: &fingerprint)
            }
            mix(body.mass.kilograms.bitPattern, into: &fingerprint)
            mix(body.radius.meters.bitPattern, into: &fingerprint)
            mix(body.rail.semiMajorAxis.meters.bitPattern, into: &fingerprint)
            mix(body.rail.eccentricity.rawValue.bitPattern, into: &fingerprint)
            mix(body.rail.longitudeOfPeriapsisRadians.bitPattern, into: &fingerprint)
            mix(body.rail.meanAnomalyAtEpochRadians.bitPattern, into: &fingerprint)
            mix(body.rail.epoch.secondsSinceReferenceEpoch.bitPattern, into: &fingerprint)
            mix(body.rail.gravitationalParameter.cubicMetersPerSecondSquared.bitPattern, into: &fingerprint)
        }
        return fingerprint
    }

    private func mix(_ word: UInt64, into fingerprint: inout UInt64) {
        fingerprint ^= word
        fingerprint &*= 0x0000_0100_0000_01B3
    }
}
