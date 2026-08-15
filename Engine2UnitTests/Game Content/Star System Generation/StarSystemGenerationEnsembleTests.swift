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
        var resolvedPlanetCounts: Set<Int> = []
        var resolvedPlanetCapacities: Set<Int> = []
        var maximumMoonCount = 0

        let representativeRawSeeds = [
            0, 1, 2, 4, 6, 8, 9, 11, 12, 16, 17, 21, 25, 43, 57, 122, 151, 792
        ]
        for rawSeed in representativeRawSeeds {
            let system = try generator.generate(seed: StarSystemSeed(rawValue: UInt64(rawSeed)))
            try system.validate()
            expectResolvedBodySemantics(in: system)
            resolvedPlanetCounts.insert(system.planets.count)
            resolvedPlanetCapacities.insert(system.formationLedger.resolvedPlanetCapacity)
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
        #expect(
            waterRegimes
                == Set([.dry, .iceCovered, .partialLiquid, .globalOcean, .steam, .inaccessible])
        )
        #expect(visibleBoundaries == Set([.exposedSolid, .opaqueAtmosphere]))
        #expect(resolvedPlanetCounts == Set(0...generator.policy.maximumResolvedPlanetCount))
        #expect(resolvedPlanetCapacities == Set(0...generator.policy.maximumResolvedPlanetCount))
        #expect(maximumMoonCount >= 2)
    }

    private func expectResolvedBodySemantics(in system: GeneratedStarSystem) {
        let belowThreshold = system.planets.filter {
            resolvedSolidMassEarth(of: $0)
                < system.policy.minimumResolvedPlanetSolidMassEarth
        }
        let ledger = system.formationLedger

        #expect(belowThreshold.isEmpty)
        #expect(
            (0...system.policy.maximumResolvedPlanetCount)
                .contains(ledger.resolvedPlanetCapacity)
        )
        #expect(system.planets.count <= ledger.resolvedPlanetCapacity)
        if ledger.resolvedPlanetCapacity == 0 {
            #expect(system.planets.isEmpty)
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
        }
    }

    private func resolvedSolidMassEarth(of planet: GeneratedPlanet) -> Double {
        planet.composition.solidMass.earthMasses
            + planet.moons.reduce(0) { $0 + $1.composition.solidMass.earthMasses }
    }
}
