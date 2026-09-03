/// Example consumer content used by tests and architecture documentation.
///
/// This value owns game-specific construction and asset descriptions, but it
/// has no cadence, lifecycle, decoded model, or GPU resource of its own.
struct BasicGameContent: GameContent {
    let inputMappingConfiguration: InputMappingConfiguration

    let simulationBehavior: any SimulationBehavior

    let worldBuilder: any WorldBuilder

    let simulationConfiguration: SimulationConfiguration

    let renderAssetCatalog: RenderAssetCatalog

    /// Selects the complete basic example content.
    init() {
        self.init(worldBuilder: BasicWorldBuilder())
    }

    /// Uses a caller-supplied world construction path with the complete
    /// authored catalog owned by this Game Content.
    init(worldBuilder: any WorldBuilder) {
        self.worldBuilder = worldBuilder
        self.inputMappingConfiguration = .basicGame
        self.simulationBehavior = StandardSimulationBehavior()
        self.simulationConfiguration = .basicGame
        self.renderAssetCatalog = .everything
    }
}
