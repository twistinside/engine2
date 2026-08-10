/// Invalid Game Content supplied to the Render Runtime's catalog boundary.
nonisolated enum RenderAssetCatalogError: Error, Equatable {
    /// One or more identities in the exhaustive Game Content material
    /// vocabulary have no authored description.
    ///
    /// IDs remain in `MaterialID.allCases` order so diagnostics and tests are
    /// deterministic rather than depending on dictionary iteration order.
    case missingMaterialDescriptions([MaterialID])

    /// One or more material identities select both ordinary PBR and
    /// terrestrial-planet descriptions.
    ///
    /// A material identity must resolve to one family so Render never chooses
    /// a pipeline based on dictionary lookup order.
    case overlappingMaterialDescriptions([MaterialID])

    /// One or more texture identities referenced by a material description
    /// have no packaged source asset.
    ///
    /// IDs remain in `TextureID.allCases` order so diagnostics and tests are
    /// deterministic rather than depending on dictionary iteration order.
    case missingTextureAssets([TextureID])
}
