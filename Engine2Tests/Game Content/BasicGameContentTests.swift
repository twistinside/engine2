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

    @Test func suppliesEveryAuthoredMaterialDescription() throws {
        let catalog = BasicGameContent().renderAssetCatalog

        // Game Content owns the exhaustive identity vocabulary. Lock both its
        // complete coverage and the exact scene-linear values so moving the M3
        // proof material across the boundary cannot alter the visible baseline.
        try catalog.validateMaterialCoverage()
        #expect(Set(catalog.materials.keys) == Set(MaterialID.allCases))
        #expect(
            try catalog.materialDescription(for: .warmDielectric)
                == PBRMaterialDescription(
                    baseColor: SIMD3<Float>(0.5, 0.25, 0.125),
                    metallic: 0,
                    perceptualRoughness: 0.5
                )
        )
        #expect(
            try catalog.materialDescription(for: .goldMetal)
                == PBRMaterialDescription(
                    baseColor: SIMD3<Float>(1, 0.766, 0.336),
                    metallic: 1,
                    perceptualRoughness: 0.35
                )
        )
    }
}
