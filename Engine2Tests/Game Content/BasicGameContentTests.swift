//
//  BasicGameContentTests.swift
//  Engine2Tests
//
//  Created by Codex on 7/15/26.
//

import Metal
import Testing
@testable import Engine2

struct BasicGameContentTests {
    @Test func mapsBallMeshIdentityToPackagedBallModel() async throws {
        let content = BasicGameContent()

        #expect(
            content.renderAssetCatalog.models[.ball] == ModelAssetReference(
                resourceName: "Ball",
                format: .usdz
            )
        )
    }

    @MainActor
    @Test func packagedBallModelResolvesIntoRendererOwnedMeshes() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let models = try USDRenderModel.load(
            catalog: BasicGameContent().renderAssetCatalog,
            device: device
        )

        #expect(models[.ball]?.meshes.isEmpty == false)
    }
}
