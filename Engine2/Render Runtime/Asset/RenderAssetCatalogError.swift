/// Invalid Game Content supplied to the Render Runtime's catalog boundary.
nonisolated enum RenderAssetCatalogError: Error, Equatable {
    /// One or more identities in the exhaustive Game Content material
    /// vocabulary have no authored description.
    ///
    /// IDs remain in `MaterialID.allCases` order so diagnostics and tests are
    /// deterministic rather than depending on dictionary iteration order.
    case missingMaterialDescriptions([MaterialID])
}
