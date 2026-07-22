import Testing
@testable import Engine2

struct RealtimeConfigurationTests {
    @Test @MainActor func makeAssemblyUsesConfigurationAndGameContent() throws {
        let configuration = RealtimeConfiguration(
            fixedTimeStep: .milliseconds(20),
            pollInterval: .seconds(60)
        )
        let gameContent = BasicGameContent(
            worldBuilder: RealtimeTestWorldBuilder(position: SIMD3<Float>(3, 4, 5))
        )

        let assembly = configuration.makeAssembly(gameContent: gameContent)
        let entity = try #require(
            assembly.simulationRuntime.world.positionComponents.entities.first
        )

        #expect(assembly.simulationRuntime.state.fixedTimeStep == .milliseconds(20))
        #expect(
            assembly.simulationRuntime.world.positionComponents[entity]?.position ==
            SIMD3<Float>(3, 4, 5)
        )
        #expect(assembly.inputRuntime.isRunning == false)
        #expect(assembly.simulationRuntime.state.isLoopRunning == false)
        #expect(assembly.simulationRuntime.state.isRunning == false)
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
