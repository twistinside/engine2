import Testing
@testable import Engine2

struct RealtimeConfigurationTests {
    @Test @MainActor func makeAssemblyUsesConfigurationAndGameContent() throws {
        let configuration = RealtimeConfiguration(
            fixedTimeStep: .milliseconds(20),
            pollInterval: .seconds(60),
            catchUpPolicy: RealtimeCatchUpPolicy(
                maximumStepsPerWake: SimulationStepCount(rawValue: 2),
                backlogTreatment: .preserve
            )
        )
        let gameContent = BasicGameContent(
            worldBuilder: RealtimeTestWorldBuilder(position: SIMD3<Float>(3, 4, 5))
        )

        let assembly = configuration.makeAssembly(gameContent: gameContent)
        let entity = try #require(
            assembly.simulationRuntime.world.positionComponents.entities.first
        )

        #expect(assembly.simulationRuntime.fixedTimeStep == .milliseconds(20))
        #expect(assembly.advanceDriver.fixedTimeStep == .milliseconds(20))
        #expect(assembly.advanceDriver.pollInterval == .seconds(60))
        #expect(assembly.advanceDriver.catchUpPolicy == configuration.catchUpPolicy)
        #expect(
            assembly.simulationRuntime.world.positionComponents[entity]?.position ==
            SIMD3<Float>(3, 4, 5)
        )
        #expect(assembly.inputRuntime.isRunning == false)
        #expect(assembly.advanceDriver.isRunning == false)

        let defaultCamera = assembly.simulationRuntime.latestPresentationSnapshot.camera
        let viewpoint = assembly.screenViewpointController.resolveViewpoint(
            defaultCamera: defaultCamera
        )
        #expect(viewpoint.camera == defaultCamera)
        #expect(viewpoint.revision == .zero)
    }

    @Test @MainActor func assembliesOwnIsolatedRuntimeInstances() {
        let configuration = RealtimeConfiguration(pollInterval: .seconds(60))
        let gameContent = BasicGameContent(
            worldBuilder: RealtimeTestWorldBuilder(position: .zero)
        )

        let first = configuration.makeAssembly(gameContent: gameContent)
        let second = configuration.makeAssembly(gameContent: gameContent)

        #expect(first !== second)
        #expect(first.inputRuntime !== second.inputRuntime)
        #expect(first.simulationRuntime !== second.simulationRuntime)
        #expect(first.advanceDriver !== second.advanceDriver)
        #expect(first.screenViewpointController !== second.screenViewpointController)
        #expect(first.simulationRuntime.world !== second.simulationRuntime.world)
    }
}

private struct RealtimeTestWorldBuilder: PWorldBuilder {
    let position: SIMD3<Float>

    func buildWorld() -> World {
        let world = World()
        _ = Ball(in: world, position: position)
        return world
    }
}
