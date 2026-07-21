/// Render-owned input contract for backend-neutral Game Content descriptions.
///
/// Game Content populates this value with its exhaustive identities and
/// authored source descriptions. The Render Runtime validates and resolves
/// those values privately; decoded models and Metal resources never enter the
/// catalog.
nonisolated struct RenderAssetCatalog: Equatable, Sendable {
    /// Packaged source assets keyed by Game Content mesh identity.
    let models: [MeshID: ModelAssetReference]

    /// Authored PBR factors keyed by Game Content material identity.
    let materials: [MaterialID: PBRMaterialDescription]

    init(
        models: [MeshID: ModelAssetReference],
        materials: [MaterialID: PBRMaterialDescription]
    ) {
        self.models = models
        self.materials = materials
    }

    /// Verifies that every identity in Game Content's closed material
    /// vocabulary has an authored description before rendering can begin.
    ///
    /// Dictionary iteration order is deliberately irrelevant. Missing values
    /// are collected in `MaterialID.allCases` order so the resulting error is
    /// stable across launches and platforms.
    func validateMaterialCoverage() throws {
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
    func materialDescription(
        for id: MaterialID
    ) throws -> PBRMaterialDescription {
        guard let description = materials[id] else {
            throw RenderAssetCatalogError.missingMaterialDescriptions([id])
        }

        return description
    }
}
