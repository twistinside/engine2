import Engine2

public extension RenderAssetCatalog {
    /// Complete render catalog for every asset declared by Basic Game Content.
    static let everything: Self = {
        // The dielectric row holds one scene-linear base color and metallic
        // factor constant so roughness is the only variable.
        let warmBaseColor = SIMD3<Float>(0.5, 0.25, 0.125)

        // The metal row follows the same controlled progression while
        // preserving the established M4 gold baseline at roughness 0.35.
        let goldBaseColor = SIMD3<Float>(1, 0.766, 0.336)

        return Self(
            models: [
                MeshID.ball.assetKey: ModelAssetReference(
                    resourceURL: BasicGameContentResources.ballModelURL,
                    format: .usdz
                )
            ],
            materials: [
                MaterialID.warmDielectricSmooth.assetKey: PBRMaterialDescription(
                    baseColor: warmBaseColor,
                    metallic: 0,
                    perceptualRoughness: 0.2
                ),
                MaterialID.warmDielectric.assetKey: PBRMaterialDescription(
                    baseColor: warmBaseColor,
                    metallic: 0,
                    perceptualRoughness: 0.5
                ),
                MaterialID.warmDielectricRough.assetKey: PBRMaterialDescription(
                    baseColor: warmBaseColor,
                    metallic: 0,
                    perceptualRoughness: 0.8
                ),
                MaterialID.goldMetalSmooth.assetKey: PBRMaterialDescription(
                    baseColor: goldBaseColor,
                    metallic: 1,
                    perceptualRoughness: 0.2
                ),
                MaterialID.goldMetal.assetKey: PBRMaterialDescription(
                    baseColor: goldBaseColor,
                    metallic: 1,
                    perceptualRoughness: 0.35
                ),
                MaterialID.goldMetalRough.assetKey: PBRMaterialDescription(
                    baseColor: goldBaseColor,
                    metallic: 1,
                    perceptualRoughness: 0.8
                )
            ],
            requiredMaterialKeys: MaterialID.allCases.map(\.assetKey)
        )
    }()
}
