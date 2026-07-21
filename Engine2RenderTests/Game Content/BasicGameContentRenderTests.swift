import Metal
import Testing
@testable import Engine2

struct BasicGameContentRenderTests {
    @MainActor
    @Test func packagedBallModelResolvesIntoRendererOwnedMeshes() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let models = try USDRenderModel.load(
            catalog: BasicGameContent().renderAssetCatalog,
            device: device
        )

        #expect(models.count == 1)
        #expect(models[.ball]?.meshes.isEmpty == false)
    }
}
