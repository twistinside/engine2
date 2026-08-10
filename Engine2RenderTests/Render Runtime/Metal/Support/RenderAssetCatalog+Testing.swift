@testable import Engine2

/// Test-target-only catalog fixtures stay out of the production-owned
/// `RenderAssetCatalog.swift` file so they cannot become Engine2 API.
extension RenderAssetCatalog {
    /// Complete authored appearances and texture maps without packaged models.
    ///
    /// Metal infrastructure tests often need the real material contract while
    /// supplying analytic geometry. Deriving every material family and texture
    /// from `BasicGameContent` keeps one authored source of truth while avoiding
    /// model decoding in tests that never issue an indexed model draw.
    static var materialOnlyTestCatalog: RenderAssetCatalog {
        let catalog = BasicGameContent().renderAssetCatalog

        return RenderAssetCatalog(
            models: [:],
            materials: catalog.materials,
            terrestrialPlanets: catalog.terrestrialPlanets,
            textures: catalog.textures
        )
    }
}
