import Metal
import Testing
@testable import Engine2
@testable import BasicGameContent

struct BasicGameContentRenderTests {
    @Test func packagedBallModelResolvesIntoRendererOwnedMeshes() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let models = try USDRenderModel.load(
            catalog: BasicGameContent().renderAssetCatalog,
            device: device
        )

        #expect(models.count == 1)
        #expect(models[MeshID.ball.assetKey]?.meshes.isEmpty == false)
    }
}
