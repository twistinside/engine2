import Foundation
import Testing
@testable import Engine2

nonisolated struct StarSystemPhysicalInvariantTests {
    private let generator = StarSystemGenerator(policy: .coreAccretionLiteV1)

    @Test func stellarAndDiskSamplesStayInsideVersionOneBounds() throws {
        let system = try generator.generate(seed: StarSystemSeed(rawValue: 5))
        let star = system.star
        let disk = system.protoplanetaryDisk

        #expect((0.5...1.2).contains(star.mass.solarMasses))
        #expect((-0.5...0.5).contains(star.metallicityDex))
        #expect(star.age.gigayears >= 0.5)
        #expect(star.age.gigayears <= 10)
        #expect((1...10).contains(disk.lifetime.megayears))
        #expect(disk.innerEdge < disk.outerEdge)
        #expect(disk.initialGasMass > disk.initialSolidMass)
        #expect(
            disk.initialGasMass.solarMasses / star.mass.solarMasses
                <= system.policy.maximumDiskMassRatio
        )
        #expect((10...100).contains(disk.characteristicRadius.astronomicalUnits))
        #expect(disk.outerEdge.astronomicalUnits <= 150)
        #expect(
            disk.outerEdge.astronomicalUnits
                <= 5 * disk.characteristicRadius.astronomicalUnits
        )
        let profile = ProtoplanetaryDiskProfile(
            characteristicRadiusAU: disk.characteristicRadius.astronomicalUnits,
            surfaceDensityExponent: disk.surfaceDensityExponent,
            innerEdgeAU: disk.innerEdge.astronomicalUnits,
            annulusCount: disk.annulusCount
        )
        let minimumToomreQ = profile.minimumToomreQ(
            gasMass: disk.initialGasMass,
            around: star
        )

        #expect(minimumToomreQ + 1e-9 >= ProtoplanetaryDiskProfile.minimumSupportedToomreQ)
    }

    @Test func conservedSolidAndGasLedgersClose() throws {
        let system = try generator.generate(seed: StarSystemSeed(rawValue: 6))
        let ledger = system.formationLedger
        let dynamicalComposition = ledger.dynamicalLosses.ejectedComposition
            .adding(ledger.dynamicalLosses.starAccretedComposition)
            .adding(ledger.dynamicalLosses.collisionDebrisComposition)
        let solidClosure = ledger.retainedSolidMass.earthMasses
            + ledger.unaccretedSolidMass.earthMasses
            + ledger.residualBodyComposition.solidMass.earthMasses
            + dynamicalComposition.solidMass.earthMasses
        let gasClosure = ledger.retainedHydrogenHeliumMass.earthMasses
            + ledger.escapedHydrogenHeliumMass.earthMasses
            + ledger.dispersedGasMass.earthMasses
            + ledger.residualBodyComposition.hydrogenHelium.earthMasses
            + dynamicalComposition.hydrogenHelium.earthMasses

        #expect(relativeDifference(solidClosure, ledger.initialSolidMass.earthMasses) < 1e-9)
        #expect(relativeDifference(gasClosure, ledger.initialGasMass.earthMasses) < 1e-9)
    }

    @Test func finalPlanetsAreOrderedAndConservativelyHillSpaced() throws {
        let system = try generatedSystem(minimumPlanetCount: 2)
        let planets = system.planets

        #expect(planets.count >= 2)
        #expect(planets == planets.sorted { $0.orbit.semiMajorAxis < $1.orbit.semiMajorAxis })
        for index in 0..<(planets.count - 1) {
            let inner = planets[index]
            let outer = planets[index + 1]
            let clearance = inner.orbitalClearance(to: outer, around: system.star.mass)
            let requiredSpacing = system.policy.requiredFinalSpacing(
                between: inner.mass,
                and: outer.mass
            )

            #expect(clearance.mutualHillSpacing + 1e-10 >= requiredSpacing)
            #expect(system.policy.acceptsRadialClearance(clearance, additiveSlack: 1e-10))
        }
    }

    @Test func representativeMoonSystemsUseBothOriginsAndValidatedBounds() throws {
        var moons: [GeneratedMoon] = []
        var origins: Set<MoonFormationOrigin> = []

        for rawSeed in 0..<256 {
            let system = try generator.generate(
                seed: StarSystemSeed(rawValue: UInt64(rawSeed))
            )
            let generatedMoons = system.planets.flatMap(\.moons)
            moons.append(contentsOf: generatedMoons)
            origins.formUnion(generatedMoons.map(\.origin))
            if origins.contains(.giantImpact)
                && origins.contains(.circumplanetaryDisk) {
                break
            }
        }

        #expect(!moons.isEmpty)
        #expect(origins.contains(.giantImpact))
        #expect(origins.contains(.circumplanetaryDisk))
        for moon in moons {
            #expect(moon.orbit.semiMajorAxis >= moon.minimumStableOrbit)
            #expect(moon.orbit.semiMajorAxis <= moon.maximumStableOrbit)
        }
    }

    @Test func meanFluxUsesLuminosityDistanceAndEccentricity() throws {
        let system = try generatedSystem(minimumPlanetCount: 1)

        #expect(!system.planets.isEmpty)
        for planet in system.planets {
            let axis = planet.orbit.semiMajorAxis.astronomicalUnits
            let eccentricity = planet.orbit.eccentricity.rawValue
            let expected = system.star.luminosity.solarLuminosities
                / (axis * axis * sqrt(1 - eccentricity * eccentricity))
            #expect(relativeDifference(planet.environment.incidentFluxEarth, expected) < 1e-12)
        }
    }

    private func generatedSystem(
        minimumPlanetCount: Int
    ) throws -> GeneratedStarSystem {
        var match: GeneratedStarSystem?
        for rawSeed in 0..<64 {
            let system = try generator.generate(
                seed: StarSystemSeed(rawValue: UInt64(rawSeed))
            )
            if system.planets.count >= minimumPlanetCount {
                match = system
                break
            }
        }
        return try #require(
            match,
            "The bounded seed range must include the requested resolved-planet population."
        )
    }

    private func relativeDifference(_ first: Double, _ second: Double) -> Double {
        abs(first - second) / max(abs(first), abs(second), 1)
    }
}
