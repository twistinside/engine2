/// Render-owned input contract for backend-neutral Game Content descriptions.
///
/// Game Content populates this value with its exhaustive identities and
/// authored source descriptions. The Render Runtime validates and resolves
/// those values privately; decoded models and Metal resources never enter the
/// catalog.
nonisolated public struct RenderAssetCatalog: Equatable, Sendable {
    /// Packaged source assets keyed by Game Content mesh identity.
    public let models: [MeshAssetKey: ModelAssetReference]

    /// Authored PBR factors keyed by Game Content material identity.
    public let materials: [MaterialAssetKey: PBRMaterialDescription]

    /// Complete ordered material vocabulary that Render construction requires.
    public let requiredMaterialKeys: [MaterialAssetKey]

    /// Creates one catalog in the namespace selected by its Game Content package.
    ///
    /// Required material keys must be unique. Their order becomes the stable
    /// diagnostic order for missing authored descriptions.
    public init(
        models: [MeshAssetKey: ModelAssetReference],
        materials: [MaterialAssetKey: PBRMaterialDescription],
        requiredMaterialKeys: [MaterialAssetKey]
    ) {
        precondition(
            Set(requiredMaterialKeys).count == requiredMaterialKeys.count,
            "Required material keys must be unique."
        )

        self.models = models
        self.materials = materials
        self.requiredMaterialKeys = requiredMaterialKeys
    }

    /// Verifies that every identity in Game Content's closed material
    /// vocabulary has an authored description before rendering can begin.
    ///
    /// Dictionary iteration order is deliberately irrelevant. Missing values
    /// are collected in `requiredMaterialKeys` order so the resulting error is
    /// stable across launches and platforms.
    public func validateMaterialCoverage() throws(RenderAssetCatalogError) {
        let missingMaterialIDs = requiredMaterialKeys.filter {
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
    public func materialDescription(
        for id: MaterialAssetKey
    ) throws(RenderAssetCatalogError) -> PBRMaterialDescription {
        guard let description = materials[id] else {
            throw RenderAssetCatalogError.missingMaterialDescriptions([id])
        }

        return description
    }
}
