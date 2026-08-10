import Metal
import Testing
@testable import Engine2

struct BasicGameContentRenderTests {
    @Test func packagedModelsResolveIntoRendererOwnedMeshes() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let models = try USDRenderModel.load(
            catalog: BasicGameContent().renderAssetCatalog,
            device: device
        )

        #expect(models.count == MeshID.allCases.count)
        #expect(models[.ball]?.meshes.isEmpty == false)
        #expect(models[.terrestrialPlanet]?.meshes.isEmpty == false)
    }
}
