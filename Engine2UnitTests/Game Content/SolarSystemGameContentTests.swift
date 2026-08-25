import Testing
@testable import Engine2

struct SolarSystemGameContentTests {
    @Test func selectsSolarSystemWorldCameraPolicyAndCompleteCatalog() {
        let content = SolarSystemGameContent()
        let configuration = content.simulationConfiguration

        #expect(content.worldBuilder is SolarSystemWorldBuilder)
        #expect(configuration == .solarSystem)
        #expect(configuration.simulationTimeScale == .solarSystemSmokeTest)
        #expect(configuration.simulationTimeScale.multiplier == 216_000)
        #expect(configuration.pointerOrbitSensitivity == 0.01)
        #expect(configuration.scrollZoomSensitivity == 4.0e10)
        #expect(configuration.cameraOrbitTarget == .zero)
        #expect(configuration.minimumCameraOrbitRadius == 2.0e12)
        #expect(configuration.maximumCameraOrbitRadius == 3.0e13)
        #expect(content.renderAssetCatalog == .everything)
    }

    @Test func oneProductionTickMatchesOneExplicitHourOfGravityAndMovement() {
        let content = SolarSystemGameContent()
        let productionWorld = content.worldBuilder.buildWorld()
        let referenceWorld = content.worldBuilder.buildWorld()
        let productionEngine = Engine(
            world: productionWorld,
            fixedTimeStep: SimulationRuntime.fixedTimeStep,
            configuration: content.simulationConfiguration
        )
        let referenceEngine = Engine(
            world: referenceWorld,
            fixedTimeStep: .seconds(3_600),
            systems: [SGravity(), SMovement()]
        )

        productionEngine.step()
        referenceEngine.step()

        #expect(productionWorld.positionComponents.dense == referenceWorld.positionComponents.dense)
        #expect(productionWorld.motionComponents.dense == referenceWorld.motionComponents.dense)
    }

    @Test func oneRuntimeAdvancePublishesAcceleratedMotion() async {
        let content = SolarSystemGameContent()
        let simulation = SimulationRuntime(
            worldBuilder: content.worldBuilder,
            configuration: content.simulationConfiguration,
            inputBaseline: nil
        )
        let initialSnapshot = simulation.latestPresentationSnapshot
        let request = SimulationAdvanceRequest(
            expectedCursor: initialSnapshot.cursor,
            stepCount: .one,
            inputAssignment: .none
        )

        let outcome = await simulation.advance(request)
        guard case let .completed(result) = outcome else {
            Issue.record("Expected the Solar System advance to complete, received \(outcome)")
            return
        }

        let initialPositions = initialSnapshot.entityPresentations.compactMap(\.position)
        let finalPositions = result.finalPresentationSnapshot.entityPresentations.compactMap(\.position)
        #expect(result.finalCursor.tick == SimulationTick(rawValue: 1))
        #expect(simulation.latestPresentationSnapshot == result.finalPresentationSnapshot)
        #expect(finalPositions.count == initialPositions.count)
        for index in finalPositions.indices {
            #expect(finalPositions[index].isFinite)
            #expect(finalPositions[index] != initialPositions[index])
        }
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
