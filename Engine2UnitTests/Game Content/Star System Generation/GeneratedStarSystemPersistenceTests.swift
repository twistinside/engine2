import Foundation
import Testing
@testable import Engine2

nonisolated struct GeneratedStarSystemPersistenceTests {
    private let generator = StarSystemGenerator(policy: .coreAccretionLiteV1)

    @Test func resolvedSystemRoundTripsThroughCodableThenValidates() throws {
        let original = try generator.generate(seed: StarSystemSeed(rawValue: 99))
        let data = try JSONEncoder().encode(original)

        let decoded = try JSONDecoder().decode(GeneratedStarSystem.self, from: data)

        #expect(decoded == original)
        try decoded.validate()
    }

    @Test func zeroPlanetSystemRoundTripsAndRetainsResidualProvenance() throws {
        let original = try generator.generate(seed: StarSystemSeed(rawValue: 43))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GeneratedStarSystem.self, from: data)

        #expect(original.formationLedger.resolvedPlanetCapacity == 0)
        #expect(original.planets.isEmpty)
        #expect(original.formationLedger.retainedSolidMass == .zero)
        #expect(original.formationLedger.retainedHydrogenHeliumMass == .zero)
        #expect(original.formationLedger.residualBodyCount > 0)
        #expect(decoded == original)
        try decoded.validate()
    }

    @Test func validationRejectsDecodedPolicyThatBypassedTrustedInitializer() throws {
        let original = try generator.generate(seed: StarSystemSeed(rawValue: 101))
        let decoded = try GeneratedStarSystemFixture(system: original).decoded { object in
            var policy = try #require(object["policy"] as? [String: Any])
            policy["annulusCount"] = 0
            object["policy"] = policy
        }

        #expect(throws: StarSystemGenerationError.invalidPolicy) {
            try decoded.validate()
        }
        #expect(throws: StarSystemGenerationError.invalidPolicy) {
            _ = try StarSystemGenerator(policy: decoded.policy).generate(seed: decoded.seed)
        }
    }

    @Test func validationRejectsAValidButNoncanonicalVersionOnePolicy() throws {
        let original = try generator.generate(seed: StarSystemSeed(rawValue: 103))
        let decoded = try GeneratedStarSystemFixture(system: original).decoded { object in
            var policy = try #require(object["policy"] as? [String: Any])
            policy["solidAccretionEfficiency"] = 0.44
            object["policy"] = policy
        }

        #expect(decoded.policy.isValid)
        #expect(!decoded.policy.isSupportedCalibration)
        #expect(throws: StarSystemGenerationError.invalidPolicy) {
            try decoded.validate()
        }
        #expect(throws: StarSystemGenerationError.invalidPolicy) {
            _ = try StarSystemGenerator(policy: decoded.policy).generate(seed: decoded.seed)
        }
    }

    @Test func validationRejectsCorruptedDerivedEnvironment() throws {
        let original = try generator.generate(seed: StarSystemSeed(rawValue: 106))
        let planet = try #require(original.planets.first)
        let environment = planet.environment
        let invalidEnvironment = PlanetaryEnvironment(
            incidentFluxEarth: environment.incidentFluxEarth * 1.1,
            equilibriumTemperature: environment.equilibriumTemperature,
            visibleBoundaryTemperature: environment.visibleBoundaryTemperature,
            atmosphereMass: environment.atmosphereMass,
            surfacePressure: environment.surfacePressure,
            bondAlbedo: environment.bondAlbedo,
            liquidWaterCoverage: environment.liquidWaterCoverage,
            waterIceCoverage: environment.waterIceCoverage
        )
        let invalidPlanet = GeneratedPlanet(
            id: planet.id,
            composition: planet.composition,
            radius: planet.radius,
            orbit: planet.orbit,
            environment: invalidEnvironment,
            physicalState: planet.physicalState,
            moons: planet.moons,
            progenitorCount: planet.progenitorCount
        )
        var planets = original.planets
        planets[0] = invalidPlanet
        let invalid = GeneratedStarSystemFixture(system: original).replacingPlanets(planets)

        #expect(throws: StarSystemGenerationError.inconsistentDerivedBody(planet.id)) {
            try invalid.validate()
        }
    }

    @Test func validationRejectsCorruptedReplayedStarAndDiskFacts() throws {
        let original = try generator.generate(seed: StarSystemSeed(rawValue: 108))
        let fixture = GeneratedStarSystemFixture(system: original)
        let starCorruption = try fixture.decoded { object in
            var star = try #require(object["star"] as? [String: Any])
            var luminosity = try #require(star["luminosity"] as? [String: Any])
            let watts = try #require(luminosity["watts"] as? Double)
            luminosity["watts"] = watts * 1.01
            star["luminosity"] = luminosity
            object["star"] = star
        }
        let diskCorruption = try fixture.decoded { object in
            var disk = try #require(object["protoplanetaryDisk"] as? [String: Any])
            var radius = try #require(disk["characteristicRadius"] as? [String: Any])
            let meters = try #require(radius["meters"] as? Double)
            radius["meters"] = meters * 1.01
            disk["characteristicRadius"] = radius
            object["protoplanetaryDisk"] = disk
        }

        #expect(throws: StarSystemGenerationError.invalidStar) {
            try starCorruption.validate()
        }
        #expect(throws: StarSystemGenerationError.invalidDisk) {
            try diskCorruption.validate()
        }
    }

    @Test func validationRejectsCorruptedPlanetAncestry() throws {
        let original = try generator.generate(seed: StarSystemSeed(rawValue: 109))
        let decoded = try GeneratedStarSystemFixture(system: original).decoded { object in
            var planets = try #require(object["planets"] as? [[String: Any]])
            var planet = try #require(planets.first)
            let progenitorCount = try #require(planet["progenitorCount"] as? Int)
            planet["progenitorCount"] = progenitorCount + 1
            planets[0] = planet
            object["planets"] = planets
        }

        #expect(throws: StarSystemGenerationError.invalidFormationLedger) {
            try decoded.validate()
        }
    }

    @Test func validationRejectsPlanetInsideTheModeledDiskInnerEdge() throws {
        let original = try generator.generate(seed: StarSystemSeed(rawValue: 110))
        let bodyID = try #require(original.planets.first?.id)
        let invalidSemiMajorAxis = (
            original.star.radius.meters + original.protoplanetaryDisk.innerEdge.meters
        ) / 2
        let decoded = try GeneratedStarSystemFixture(system: original).decoded { object in
            var planets = try #require(object["planets"] as? [[String: Any]])
            var planet = try #require(planets.first)
            var orbit = try #require(planet["orbit"] as? [String: Any])
            var semiMajorAxis = try #require(orbit["semiMajorAxis"] as? [String: Any])
            semiMajorAxis["meters"] = invalidSemiMajorAxis
            orbit["semiMajorAxis"] = semiMajorAxis
            planet["orbit"] = orbit
            planets[0] = planet
            object["planets"] = planets
        }

        #expect(decoded.planets[0].orbit.semiMajorAxis.meters > original.star.radius.meters)
        #expect(decoded.planets[0].orbit.semiMajorAxis < original.protoplanetaryDisk.innerEdge)
        #expect(throws: StarSystemGenerationError.invalidPlanet(bodyID)) {
            try decoded.validate()
        }
    }

    @Test func validationRejectsNoncanonicalMoonIdentityBits() throws {
        let original = try generator.generate(seed: StarSystemSeed(rawValue: 5))
        let planetIndex = try #require(original.planets.firstIndex(where: { !$0.moons.isEmpty }))
        let planet = original.planets[planetIndex]
        let moon = try #require(planet.moons.first)
        let invalidMoon = GeneratedMoon(
            id: GeneratedBodyID(rawValue: moon.id.rawValue | (1 << 62)),
            origin: moon.origin,
            composition: moon.composition,
            radius: moon.radius,
            orbit: moon.orbit,
            minimumStableOrbit: moon.minimumStableOrbit,
            maximumStableOrbit: moon.maximumStableOrbit,
            environment: moon.environment,
            physicalState: moon.physicalState
        )
        var moons = planet.moons
        moons[0] = invalidMoon
        let invalidPlanet = GeneratedPlanet(
            id: planet.id,
            composition: planet.composition,
            radius: planet.radius,
            orbit: planet.orbit,
            environment: planet.environment,
            physicalState: planet.physicalState,
            moons: moons,
            progenitorCount: planet.progenitorCount
        )
        var planets = original.planets
        planets[planetIndex] = invalidPlanet
        let invalid = GeneratedStarSystemFixture(system: original).replacingPlanets(planets)

        #expect(throws: StarSystemGenerationError.invalidMoon(invalidMoon.id)) {
            try invalid.validate()
        }
    }

    @Test func validationThrowsInsteadOfTrappingOnOverflowingDecodedComposition() throws {
        let original = try generator.generate(seed: StarSystemSeed(rawValue: 107))
        let bodyID = try #require(original.planets.first?.id)
        let decoded = try GeneratedStarSystemFixture(system: original).decoded { object in
            var planets = try #require(object["planets"] as? [[String: Any]])
            var planet = try #require(planets.first)
            var composition = try #require(planet["composition"] as? [String: Any])
            var iron = try #require(composition["iron"] as? [String: Any])
            var silicate = try #require(composition["silicate"] as? [String: Any])
            iron["kilograms"] = 1e308
            silicate["kilograms"] = 1e308
            composition["iron"] = iron
            composition["silicate"] = silicate
            planet["composition"] = composition
            planets[0] = planet
            object["planets"] = planets
        }

        #expect(throws: StarSystemGenerationError.invalidPlanet(bodyID)) {
            try decoded.validate()
        }
    }

    @Test func validationThrowsInsteadOfTrappingOnGreatestFiniteDecodedComponent() throws {
        let original = try generator.generate(seed: StarSystemSeed(rawValue: 107))
        let bodyID = try #require(original.planets.first?.id)
        let decoded = try GeneratedStarSystemFixture(system: original).decoded { object in
            var planets = try #require(object["planets"] as? [[String: Any]])
            var planet = try #require(planets.first)
            var composition = try #require(planet["composition"] as? [String: Any])
            var iron = try #require(composition["iron"] as? [String: Any])
            iron["kilograms"] = Double.greatestFiniteMagnitude
            composition["iron"] = iron
            planet["composition"] = composition
            planets[0] = planet
            object["planets"] = planets
        }

        #expect(decoded.planets[0].composition.iron.kilograms.isFinite)
        #expect(throws: StarSystemGenerationError.invalidPlanet(bodyID)) {
            try decoded.validate()
        }
    }

    @Test func validationRejectsHydrogenHeliumOnlyResolvedPlanetWithClosedLedger() throws {
        let selection = try generatedSystemWithEnvelopeBearingPlanet()
        let original = selection.system
        let planet = original.planets[selection.planetIndex]
        let originalSolid = planet.composition.replacingHydrogenHelium(with: .zero)
        let hydrogenHeliumOnly = CelestialMassComposition(
            iron: .zero,
            silicate: .zero,
            water: .zero,
            otherVolatiles: .zero,
            hydrogenHelium: planet.composition.hydrogenHelium
        )
        let invalidPlanet = GeneratedPlanet(
            id: planet.id,
            composition: hydrogenHeliumOnly,
            radius: planet.radius,
            orbit: planet.orbit,
            environment: planet.environment,
            physicalState: planet.physicalState,
            moons: planet.moons,
            progenitorCount: planet.progenitorCount
        )
        var planets = original.planets
        planets[selection.planetIndex] = invalidPlanet
        let ledger = original.formationLedger
        let invalidUnaccreted = ledger.unaccretedSolidComposition.adding(originalSolid)
        let invalidLedger = replacing(
            ledger,
            retainedSolidMass: AstronomicalMass(
                earthMasses: ledger.retainedSolidMass.earthMasses
                    - originalSolid.solidMass.earthMasses
            ),
            unaccretedSolidMass: invalidUnaccreted.solidMass,
            unaccretedSolidComposition: invalidUnaccreted
        )
        let systemWithInvalidPlanet = GeneratedStarSystemFixture(system: original).replacingPlanets(planets)
        let invalid = GeneratedStarSystemFixture(system: systemWithInvalidPlanet).replacingLedger(invalidLedger)
        let originalChangedSolidEarth = ledger.retainedSolidMass.earthMasses
            + ledger.unaccretedSolidMass.earthMasses
        let invalidChangedSolidEarth = invalidLedger.retainedSolidMass.earthMasses
            + invalidLedger.unaccretedSolidMass.earthMasses

        #expect(hydrogenHeliumOnly.solidMass == .zero)
        #expect(hydrogenHeliumOnly.hydrogenHelium > .zero)
        #expect(abs(originalChangedSolidEarth - invalidChangedSolidEarth) < 1e-9)
        #expect(invalidLedger.retainedHydrogenHeliumMass == ledger.retainedHydrogenHeliumMass)
        #expect(throws: StarSystemGenerationError.invalidPlanet(planet.id)) {
            try invalid.validate()
        }
    }

    private func generatedSystemWithEnvelopeBearingPlanet() throws -> (
        system: GeneratedStarSystem,
        planetIndex: Int
    ) {
        var match: (system: GeneratedStarSystem, planetIndex: Int)?
        for rawSeed in 0..<32 {
            let system = try generator.generate(seed: StarSystemSeed(rawValue: UInt64(rawSeed)))
            if let planetIndex = system.planets.firstIndex(where: {
                $0.composition.hydrogenHelium > .zero
            }) {
                match = (system, planetIndex)
                break
            }
        }
        return try #require(match, "The bounded seed range must include an envelope-bearing planet.")
    }

    private func replacing(
        _ ledger: StarSystemFormationLedger,
        retainedSolidMass: AstronomicalMass,
        unaccretedSolidMass: AstronomicalMass,
        unaccretedSolidComposition: CelestialMassComposition
    ) -> StarSystemFormationLedger {
        StarSystemFormationLedger(
            initialSolidMass: ledger.initialSolidMass,
            retainedSolidMass: retainedSolidMass,
            unaccretedSolidMass: unaccretedSolidMass,
            unaccretedSolidComposition: unaccretedSolidComposition,
            initialGasMass: ledger.initialGasMass,
            retainedHydrogenHeliumMass: ledger.retainedHydrogenHeliumMass,
            escapedHydrogenHeliumMass: ledger.escapedHydrogenHeliumMass,
            dispersedGasMass: ledger.dispersedGasMass,
            dynamicalLosses: ledger.dynamicalLosses,
            residualBodyComposition: ledger.residualBodyComposition,
            residualBodyCount: ledger.residualBodyCount,
            residualProgenitorCount: ledger.residualProgenitorCount,
            resolvedPlanetCapacity: ledger.resolvedPlanetCapacity,
            seededEmbryoCount: ledger.seededEmbryoCount,
            formationMergerCount: ledger.formationMergerCount,
            postDiskCollisionMergerCount: ledger.postDiskCollisionMergerCount
        )
    }
}
