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
            ],
            materials: [
                // This preserves the exact renderer-owned M3 proof appearance
                // while moving authority for the authored factors into Game
                // Content.
                .warmDielectric: PBRMaterialDescription(
                    baseColor: SIMD3<Float>(0.5, 0.25, 0.125),
                    metallic: 0,
                    perceptualRoughness: 0.5
                ),

                // A second authored appearance proves that one sphere mesh can
                // resolve distinct material content without constructing M5's
                // validation scene yet. These are scene-linear validation
                // values, not a claim of physical calibration.
                .goldMetal: PBRMaterialDescription(
                    baseColor: SIMD3<Float>(1, 0.766, 0.336),
                    metallic: 1,
                    perceptualRoughness: 0.35
                )
            ]
        )
    }
}
