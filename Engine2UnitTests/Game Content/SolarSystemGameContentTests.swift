import Testing
@testable import Engine2

struct SolarSystemGameContentTests {
    @Test func selectsSolarSystemWorldCameraPolicyAndCompleteCatalog() {
        let content = SolarSystemGameContent()
        let configuration = content.simulationConfiguration

        #expect(content.worldBuilder is SolarSystemWorldBuilder)
        #expect(configuration == .solarSystem)
        #expect(configuration.pointerOrbitSensitivity == 0.01)
        #expect(configuration.scrollZoomSensitivity == 4.0e10)
        #expect(configuration.cameraOrbitTarget == .zero)
        #expect(configuration.minimumCameraOrbitRadius == 2.0e12)
        #expect(configuration.maximumCameraOrbitRadius == 3.0e13)
        #expect(content.renderAssetCatalog == .everything)
    }

    @Test func productionCameraSystemsZoomWithoutCollapsingTheSystemView() {
        let content = SolarSystemGameContent()
        let world = content.worldBuilder.buildWorld()
        let initialProjection = world.camera.projection
        world.input.mouse.delta.x = 20
        world.input.mouse.scrollDelta.y = 10
        let engine = Engine(
            world: world,
            fixedTimeStep: .seconds(1.0 / 60.0),
            configuration: content.simulationConfiguration
        )

        engine.step()

        let camera = engine.world.camera
        let horizontalRadius = hypotf(camera.position.x, camera.position.z)
        #expect(abs(horizontalRadius - 7.6e12) < 1.0e7)
        #expect(camera.position.x > 1.0e12)
        #expect(camera.projection == initialProjection)
        #expect(camera.supportsViewTransform)
    }
}
