@testable import Engine2

/// Test-target-only catalog fixtures stay out of the production-owned
/// `RenderAssetCatalog.swift` file so they cannot become Engine2 API.
extension RenderAssetCatalog {
    /// Complete authored materials without packaged model references.
    ///
    /// Metal infrastructure tests often need the real material contract while
    /// supplying their own analytic geometry. Deriving this catalog from
    /// `BasicGameContent` keeps one source of truth for authored factors and
    /// avoids decoding `Ball.usdz` in tests that never draw that model.
    static var materialOnlyTestCatalog: RenderAssetCatalog {
        RenderAssetCatalog(
            models: [:],
            materials: BasicGameContent().renderAssetCatalog.materials
        )
    }
}
