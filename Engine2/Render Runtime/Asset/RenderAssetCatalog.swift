/// Render-owned input contract for backend-neutral Game Content descriptions.
///
/// Game Content populates this value with its exhaustive identities and
/// authored source descriptions. The Render Runtime validates and resolves
/// those values privately; decoded models and Metal resources never enter the
/// catalog.
nonisolated struct RenderAssetCatalog: Equatable, Sendable {
    /// Complete catalog for every asset declared by Basic Game Content.
    ///
    /// Callers may still construct a curated catalog with
    /// `init(models:materials:)`.
    static let everything = Self(
        models: [
            .ball: ModelAssetReference(
                resourceName: "Ball",
                format: .usdz
            )
        ],
        materials: [
            // The dielectric row holds one scene-linear base color and metallic
            // factor constant so roughness is the only variable.
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

    /// Packaged source assets keyed by Game Content mesh identity.
    let models: [MeshID: ModelAssetReference]

    /// Authored PBR factors keyed by Game Content material identity.
    let materials: [MaterialID: PBRMaterialDescription]

    /// Verifies that every identity in Game Content's closed material
    /// vocabulary has an authored description before rendering can begin.
    ///
    /// Dictionary iteration order is deliberately irrelevant. Missing values
    /// are collected in `MaterialID.allCases` order so the resulting error is
    /// stable across launches and platforms.
    func validateMaterialCoverage() throws(RenderAssetCatalogError) {
        let missingMaterialIDs = MaterialID.allCases.filter {
            materials[$0] == nil
        }

        guard missingMaterialIDs.isEmpty else {
            throw RenderAssetCatalogError.missingMaterialDescriptions(
                missingMaterialIDs
            )
        }
    }

    /// Resolves one authored material without inventing a renderer fallback.
    ///
    /// Callers that accept a partial or otherwise unvalidated catalog receive a
    /// concrete content error before encoding a draw for the missing identity.
    func materialDescription(for id: MaterialID) throws(RenderAssetCatalogError) -> PBRMaterialDescription {
        guard let description = materials[id] else {
            throw RenderAssetCatalogError.missingMaterialDescriptions([id])
        }

        return description
    }
}
