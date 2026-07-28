/// Example consumer content selected by Engine2's production Runtime Assemblies.
///
/// This value owns game-specific construction and asset descriptions, but it
/// has no cadence, lifecycle, decoded model, or GPU resource of its own.
struct BasicGameContent {
    let worldBuilder: any PWorldBuilder

    let simulationConfiguration: SimulationConfiguration

    let renderAssetCatalog: RenderAssetCatalog

    /// Selects the complete example content used by the App.
    init() {
        self.init(worldBuilder: BasicWorldBuilder())
    }

    /// Uses a caller-supplied world construction path with the complete
    /// authored catalog owned by this Game Content.
    init(worldBuilder: any PWorldBuilder) {
        self.worldBuilder = worldBuilder
        self.simulationConfiguration = .basicGame
        self.renderAssetCatalog = .everything
    }
}
