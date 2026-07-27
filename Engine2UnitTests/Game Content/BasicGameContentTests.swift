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
        let expectedModels: [MeshID: ModelAssetReference] = [
            .ball: ModelAssetReference(
                resourceName: "Ball",
                format: .usdz
            )
        ]
        #expect(RenderAssetCatalog.everything.models == expectedModels)
    }

    @Test func suppliesExactAuthoredMaterialValidationMatrix() throws {
        let catalog = RenderAssetCatalog.everything
        let warmDielectricBaseColor = SIMD3<Float>(0.5, 0.25, 0.125)
        let goldMetalBaseColor = SIMD3<Float>(1, 0.766, 0.336)
        let expectedMaterials: [MaterialID: PBRMaterialDescription] = [
            .warmDielectricSmooth: PBRMaterialDescription(
                baseColor: warmDielectricBaseColor,
                metallic: 0,
                perceptualRoughness: 0.2
            ),
            .warmDielectric: PBRMaterialDescription(
                baseColor: warmDielectricBaseColor,
                metallic: 0,
                perceptualRoughness: 0.5
            ),
            .warmDielectricRough: PBRMaterialDescription(
                baseColor: warmDielectricBaseColor,
                metallic: 0,
                perceptualRoughness: 0.8
            ),
            .goldMetalSmooth: PBRMaterialDescription(
                baseColor: goldMetalBaseColor,
                metallic: 1,
                perceptualRoughness: 0.2
            ),
            .goldMetal: PBRMaterialDescription(
                baseColor: goldMetalBaseColor,
                metallic: 1,
                perceptualRoughness: 0.35
            ),
            .goldMetalRough: PBRMaterialDescription(
                baseColor: goldMetalBaseColor,
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
