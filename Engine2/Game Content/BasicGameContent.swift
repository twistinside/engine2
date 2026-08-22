/// Example consumer content selected by Engine2's App.
///
/// This value owns game-specific construction and asset descriptions, but it
/// has no cadence, lifecycle, decoded model, or GPU resource of its own.
struct BasicGameContent: PGameContent {
    let worldBuilder: any PWorldBuilder

    let simulationConfiguration: SimulationConfiguration

    let renderAssetCatalog: RenderAssetCatalog

    /// Selects the terrestrial-planet proof scene used by the App.
    init() {
        self.init(worldBuilder: TerrestrialPlanetWorldBuilder())
    }

    /// Uses a caller-supplied world construction path with the complete
    /// authored catalog owned by this Game Content.
    init(worldBuilder: any PWorldBuilder) {
        self.worldBuilder = worldBuilder
        self.simulationConfiguration = .basicGame
        self.renderAssetCatalog = .everything
    }
}
