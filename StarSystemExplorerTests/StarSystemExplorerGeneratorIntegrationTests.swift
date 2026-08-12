import Testing

@testable import StarSystemExplorer

nonisolated struct StarSystemExplorerGeneratorIntegrationTests {
    @Test func explorerTargetGeneratesAndValidatesAResolvedSystem() throws {
        let seed = StarSystemSeed(rawValue: 1)
        let system = try StarSystemGenerator(policy: .coreAccretionLiteV1).generate(seed: seed)

        #expect(system.seed == seed)
        #expect(system.modelVersion == .coreAccretionLiteV1)
        #expect(system.planets.count == 9)
        try system.validate()
    }

    @Test func zeroResolvedPlanetsRemainAValidVisualizableSystem() throws {
        let system = try StarSystemGenerator(policy: .coreAccretionLiteV1).generate(
            seed: StarSystemSeed(rawValue: 43)
        )

        #expect(system.planets.isEmpty)
        #expect(system.formationLedger.residualBodyCount > 0)
        try system.validate()
    }
}
