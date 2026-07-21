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
                // The dielectric row holds one scene-linear base color and
                // metallic factor constant so roughness is the only variable.
                .warmDielectricSmooth: PBRMaterialDescription(
                    baseColor: SIMD3<Float>(0.5, 0.25, 0.125),
                    metallic: 0,
                    perceptualRoughness: 0.2
                ),
                .warmDielectric: PBRMaterialDescription(
                    baseColor: SIMD3<Float>(0.5, 0.25, 0.125),
                    metallic: 0,
                    perceptualRoughness: 0.5
                ),
                .warmDielectricRough: PBRMaterialDescription(
                    baseColor: SIMD3<Float>(0.5, 0.25, 0.125),
                    metallic: 0,
                    perceptualRoughness: 0.8
                ),

                // The metal row follows the same controlled progression while
                // preserving the established M4 gold baseline at roughness 0.35.
                .goldMetalSmooth: PBRMaterialDescription(
                    baseColor: SIMD3<Float>(1, 0.766, 0.336),
                    metallic: 1,
                    perceptualRoughness: 0.2
                ),
                .goldMetal: PBRMaterialDescription(
                    baseColor: SIMD3<Float>(1, 0.766, 0.336),
                    metallic: 1,
                    perceptualRoughness: 0.35
                ),
                .goldMetalRough: PBRMaterialDescription(
                    baseColor: SIMD3<Float>(1, 0.766, 0.336),
                    metallic: 1,
                    perceptualRoughness: 0.8
                )
            ]
        )
    }
}
