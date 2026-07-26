import Testing
@testable import Engine2

struct BasicGameContentTests {
    @Test func canonicalConstructionSelectsBasicWorldBuilderAndCompleteCatalog() {
        let content = BasicGameContent()

        #expect(content.worldBuilder is BasicWorldBuilder)
        #expect(content.simulationConfiguration == .basicGame)
        #expect(content.renderAssetCatalog == .everything)
    }

    @Test func selectsCompleteBasicSimulationConfiguration() {
        let configuration = BasicGameContent().simulationConfiguration

        #expect(configuration == .basicGame)
        #expect(configuration.pointerOrbitSensitivity == 0.01)
        #expect(configuration.scrollZoomSensitivity == 0.04)
        #expect(configuration.cameraOrbitTarget == .zero)
        #expect(configuration.minimumCameraOrbitRadius == 2)
        #expect(configuration.maximumCameraOrbitRadius == 30)
    }

    @Test func injectedConstructionUsesCallerWorldBuilderAndCompleteCatalog() {
        let content = BasicGameContent(worldBuilder: EmptyWorldBuilder())

        #expect(content.worldBuilder is EmptyWorldBuilder)
        #expect(content.simulationConfiguration == .basicGame)
        #expect(content.renderAssetCatalog == .everything)
    }

    @Test func mapsBallMeshIdentityToPackagedBallModel() async throws {
        #expect(
            RenderAssetCatalog.everything.models == [
                .ball: ModelAssetReference(
                    resourceName: "Ball",
                    format: .usdz
                )
            ]
        )
    }

    @Test func suppliesExactAuthoredMaterialValidationMatrix() throws {
        let catalog = RenderAssetCatalog.everything
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

private extension BasicGameContentTests {
    struct EmptyWorldBuilder: PWorldBuilder {
        func buildWorld() -> World {
            World()
        }
    }
}
