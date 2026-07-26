/// Example consumer content assembled by the App composition root.
///
/// This value owns game-specific construction and asset descriptions, but it
/// has no cadence, lifecycle, decoded model, or GPU resource of its own.
struct BasicGameContent {
    let worldBuilder: any PWorldBuilder

    let simulationConfiguration: SimulationConfiguration

    let renderAssetCatalog: RenderAssetCatalog

    /// Selects the complete example content used by the App.
    init() {
        let worldBuilder = BasicWorldBuilder()
        self.init(worldBuilder: worldBuilder)
    }

    /// Uses a caller-supplied world construction path with the complete
    /// authored catalog owned by this Game Content.
    init(worldBuilder: any PWorldBuilder) {
        self.worldBuilder = worldBuilder
        self.simulationConfiguration = .basicGame
        self.renderAssetCatalog = .everything
    }
}
