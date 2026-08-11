import Testing
@testable import Engine2

nonisolated struct StarSystemGenerationEnsembleTests {
    @Test func boundedSmokeEnsembleProducesFiniteValidatedVariety() throws {
        let generator = StarSystemGenerator(policy: .coreAccretionLiteV1)
        var bulkRegimes: Set<PlanetaryBulkRegime> = []
        var atmosphereRegimes: Set<PlanetaryAtmosphereRegime> = []
        var thermalRegimes: Set<PlanetaryThermalRegime> = []
        var waterRegimes: Set<PlanetaryWaterRegime> = []
        var visibleBoundaries: Set<PlanetaryVisibleBoundary> = []
        var maximumMoonCount = 0

        for rawSeed in 0..<32 {
            let system = try generator.generate(seed: StarSystemSeed(rawValue: UInt64(rawSeed)))
            try system.validate()
            #expect(!system.planets.isEmpty)
            expectResolvedBodySemantics(in: system)
            for planet in system.planets {
                bulkRegimes.insert(planet.physicalState.bulk)
                atmosphereRegimes.insert(planet.physicalState.atmosphere)
                thermalRegimes.insert(planet.physicalState.thermal)
                waterRegimes.insert(planet.physicalState.water)
                visibleBoundaries.insert(planet.physicalState.visibleBoundary)
                maximumMoonCount = max(maximumMoonCount, planet.moons.count)
            }
        }

        #expect(bulkRegimes == Set([.metalRich, .rocky, .volatileRich, .hydrogenHeliumDominated]))
        #expect(atmosphereRegimes == Set([.airless, .tenuous, .secondary, .deepEnvelope]))
        #expect(thermalRegimes == Set([.frozen, .temperate, .hot, .molten]))
        #expect(waterRegimes == Set([.dry, .iceCovered, .steam, .inaccessible]))
        #expect(visibleBoundaries == Set([.exposedSolid, .opaqueAtmosphere]))
        #expect(maximumMoonCount >= 2)
    }

    private func expectResolvedBodySemantics(in system: GeneratedStarSystem) {
        let belowThreshold = system.planets.filter {
            resolvedSolidMassEarth(of: $0)
                < system.policy.minimumResolvedPlanetSolidMassEarth
        }
        let ledger = system.formationLedger

        #expect(belowThreshold.count <= 1)
        if !belowThreshold.isEmpty {
            #expect(system.planets.count == 1)
        }
        #expect(
            (ledger.residualBodyCount == 0)
                == (
                    ledger.residualProgenitorCount == 0
                        && ledger.residualBodyComposition == .zero
                )
        )
        if ledger.residualBodyCount > 0 {
            #expect(ledger.residualProgenitorCount >= ledger.residualBodyCount)
            #expect(
                ledger.residualBodyComposition.solidMass.earthMasses
                    < system.policy.minimumResolvedPlanetSolidMassEarth
                        * Double(ledger.residualBodyCount)
            )
        }
    }

    private func resolvedSolidMassEarth(of planet: GeneratedPlanet) -> Double {
        planet.composition.solidMass.earthMasses
            + planet.moons.reduce(0) { $0 + $1.composition.solidMass.earthMasses }
    }
}
