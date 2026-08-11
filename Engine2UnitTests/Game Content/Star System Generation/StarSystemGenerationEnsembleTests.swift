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
            waterRegimes == Set([.dry, .iceCovered, .partialLiquid, .globalOcean, .steam, .inaccessible])
        )
        #expect(visibleBoundaries == Set([.exposedSolid, .opaqueAtmosphere]))
        #expect(maximumMoonCount >= 2)
    }
}
