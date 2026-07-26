import Metal
import Testing
@testable import Engine2

struct BasicGameContentRenderTests {
    @Test func packagedBallModelResolvesIntoRendererOwnedMeshes() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let gameContent = BasicGameContent()
        let models = try USDRenderModel.load(
            catalog: gameContent.renderAssetCatalog,
            device: device
        )

        #expect(models.count == 1)
        #expect(models[.ball]?.meshes.isEmpty == false)
    }
}
