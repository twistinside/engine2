import Testing
@testable import Engine2

struct MiningGameContentTests {
    @Test func selectsTheCompleteMiningRuntimePolicy() {
        let content = MiningGameContent()

        #expect(content.inputMappingConfiguration == .miningGame)
        #expect(content.simulationConfiguration == .miningGame)
        #expect(content.simulationConfiguration.cameraOrbitAxis == SIMD3<Float>(0, 0, 1))
        #expect(content.simulationBehavior is MiningSimulationBehavior)
        #expect(content.worldBuilder is MiningWorldBuilder)
        #expect(content.renderAssetCatalog == .everything)
    }
}
