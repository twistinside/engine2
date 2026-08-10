import Foundation
import Testing
@testable import Engine2

struct BasicGameContentTests {
    @Test func canonicalConstructionSelectsPlanetWorldBuilderAndCompleteCatalog() {
        let content = BasicGameContent()

        #expect(content.worldBuilder is TerrestrialPlanetWorldBuilder)
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

    @Test func mapsEveryMeshIdentityToAnExactPackagedModelURL() throws {
        let models = RenderAssetCatalog.everything.models
        let ball = try #require(models[.ball])
        let planet = try #require(models[.terrestrialPlanet])

        #expect(models.count == MeshID.allCases.count)
        #expect(ball.resourceURL.lastPathComponent == "Ball.usdz")
        #expect(ball.format == .usdz)
        #expect(planet.resourceURL.lastPathComponent == "TerrestrialPlanet.usdz")
        #expect(planet.format == .usdz)
    }

    @Test func mapsEveryPlanetTextureWithItsRequiredInterpretation() throws {
        let textures = RenderAssetCatalog.everything.textures
        let elevation = try #require(textures[.terrestrialPlanetElevation])
        let surface = try #require(textures[.terrestrialPlanetSurface])
        let control = try #require(textures[.terrestrialPlanetControl])
        let clouds = try #require(textures[.terrestrialPlanetClouds])

        #expect(textures.count == TextureID.allCases.count)
        #expect(elevation.resourceURL.lastPathComponent == "TerrestrialPlanetElevation.png")
        #expect(elevation.interpretation == .linear)
        #expect(surface.resourceURL.lastPathComponent == "TerrestrialPlanetSurface.png")
        #expect(surface.interpretation == .sRGB)
        #expect(control.resourceURL.lastPathComponent == "TerrestrialPlanetControl.png")
        #expect(control.interpretation == .linear)
        #expect(clouds.resourceURL.lastPathComponent == "TerrestrialPlanetClouds.png")
        #expect(clouds.interpretation == .linear)
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

    @Test func suppliesExactTerrestrialPlanetDescription() throws {
        let catalog = RenderAssetCatalog.everything
        let description = try #require(
            catalog.terrestrialPlanets[.terrestrialPlanet]
        )

        #expect(catalog.terrestrialPlanets.count == 1)
        #expect(description.elevationTextureID == .terrestrialPlanetElevation)
        #expect(description.surfaceTextureID == .terrestrialPlanetSurface)
        #expect(description.controlTextureID == .terrestrialPlanetControl)
        #expect(description.cloudTextureID == .terrestrialPlanetClouds)
        #expect(description.surfaceRadius == 1)
        #expect(description.maximumRelief == 0.006)
        #expect(description.seaLevel == 0.5)
        #expect(description.cloudRadius == 1.008)
        #expect(description.atmosphereRadius == 1.018)
        #expect(description.cloudOpacity == 0.82)
        #expect(description.atmosphereIntensity == 0.32)
        #expect(description.cloudShadowStrength == 0.16)
    }
}

private extension BasicGameContentTests {
    struct EmptyWorldBuilder: PWorldBuilder {
        func buildWorld() -> World {
            World()
        }
    }
}
