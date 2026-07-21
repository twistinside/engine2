@testable import Engine2

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
