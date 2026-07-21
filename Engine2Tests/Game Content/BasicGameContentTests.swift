import Metal
import Testing
@testable import Engine2

struct BasicGameContentTests {
    @Test func mapsBallMeshIdentityToPackagedBallModel() async throws {
        let content = BasicGameContent()

        #expect(
            content.renderAssetCatalog.models == [
                .ball: ModelAssetReference(
                    resourceName: "Ball",
                    format: .usdz
                )
            ]
        )
    }

    @MainActor
    @Test func packagedBallModelResolvesIntoRendererOwnedMeshes() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let models = try USDRenderModel.load(
            catalog: BasicGameContent().renderAssetCatalog,
            device: device
        )

        #expect(models.count == 1)
        #expect(models[.ball]?.meshes.isEmpty == false)
    }

    @Test func suppliesExactAuthoredMaterialValidationMatrix() throws {
        let catalog = BasicGameContent().renderAssetCatalog
        let expectedMaterials: [MaterialID: PBRMaterialDescription] = [
            .warmDielectricSmooth: PBRMaterialDescription(
                baseColor: SIMD3<Float>(0.5, 0.25, 0.125),
                metallic: 0,
                perceptualRoughness: 0.2
            ),
            .warmDielectric: PBRMaterialDescription(
                baseColor: SIMD3<Float>(0.5, 0.25, 0.125),
                metallic: 0,
                perceptualRoughness: 0.5
            ),
            .warmDielectricRough: PBRMaterialDescription(
                baseColor: SIMD3<Float>(0.5, 0.25, 0.125),
                metallic: 0,
                perceptualRoughness: 0.8
            ),
            .goldMetalSmooth: PBRMaterialDescription(
                baseColor: SIMD3<Float>(1, 0.766, 0.336),
                metallic: 1,
                perceptualRoughness: 0.2
            ),
            .goldMetal: PBRMaterialDescription(
                baseColor: SIMD3<Float>(1, 0.766, 0.336),
                metallic: 1,
                perceptualRoughness: 0.35
            ),
            .goldMetalRough: PBRMaterialDescription(
                baseColor: SIMD3<Float>(1, 0.766, 0.336),
                metallic: 1,
                perceptualRoughness: 0.8
            )
        ]

        // Equality rejects missing, extra, or changed descriptions. Coverage
        // validation separately proves the dictionary satisfies the exhaustive
        // Game Content vocabulary consumed by Render construction.
        try catalog.validateMaterialCoverage()
        #expect(catalog.materials == expectedMaterials)
    }
}
