/// Example consumer content assembled by the App composition root.
///
/// This value owns game-specific construction and asset descriptions, but it
/// has no cadence, lifecycle, decoded model, or GPU resource of its own.
struct BasicGameContent {
    let worldBuilder: any PWorldBuilder

    let renderAssetCatalog: RenderAssetCatalog

    init(worldBuilder: any PWorldBuilder = BasicWorldBuilder()) {
        self.worldBuilder = worldBuilder
        self.renderAssetCatalog = RenderAssetCatalog(
            models: [
                .ball: ModelAssetReference(
                    resourceName: "Ball",
                    format: .usdz
                )
            ]
        )
    }

}
