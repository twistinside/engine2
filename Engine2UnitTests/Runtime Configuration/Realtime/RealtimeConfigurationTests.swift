import Testing
@testable import Engine2

struct RealtimeConfigurationTests {
    @Test func makeAssemblyUsesConfigurationAndGameContent() throws {
        let configuration = RealtimeConfiguration(
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

        #expect(assembly.advanceDriver.fixedTimeStep == SimulationRuntime.fixedTimeStep)
        #expect(assembly.advanceDriver.pollInterval == .seconds(60))
        #expect(assembly.advanceDriver.catchUpPolicy == configuration.catchUpPolicy)
        #expect(
            assembly.simulationRuntime.world.positionComponents[entity]?.position ==
            SIMD3<Float>(3, 4, 5)
        )
        #expect(assembly.inputRuntime.isRunning == false)
        #expect(assembly.advanceDriver.isRunning == false)
        #expect(
            assembly.simulationRuntime.latestPresentationSnapshot.camera
                == assembly.simulationRuntime.world.camera
        )
    }

    @Test func assembliesOwnIsolatedRuntimeInstances() {
        let configuration = RealtimeConfiguration(
            pollInterval: .seconds(60),
            catchUpPolicy: .interactive
        )
        let gameContent = BasicGameContent(
            worldBuilder: RealtimeTestWorldBuilder(position: .zero)
        )

        let first = configuration.makeAssembly(gameContent: gameContent)
        let second = configuration.makeAssembly(gameContent: gameContent)

        #expect(first !== second)
        #expect(first.inputRuntime !== second.inputRuntime)
        #expect(first.simulationRuntime !== second.simulationRuntime)
        #expect(first.advanceDriver !== second.advanceDriver)
        #expect(first.simulationRuntime.world !== second.simulationRuntime.world)
    }

    @Test func fixedStepPollingPolicyIsSelectedExplicitly() {
        let configuration = RealtimeConfiguration(
            pollInterval: SimulationRuntime.fixedTimeStep,
            catchUpPolicy: .interactive
        )

        let assembly = configuration.makeAssembly(gameContent: BasicGameContent())

        #expect(assembly.advanceDriver.pollInterval == SimulationRuntime.fixedTimeStep)
    }
}

private extension RealtimeConfigurationTests {
    private struct RealtimeTestWorldBuilder: PWorldBuilder {
        let position: SIMD3<Float>

        func buildWorld() -> World {
            let world = World()
            _ = Ball(
                in: world,
                materialID: .warmDielectric,
                position: position
            )
            return world
        }
    }
}
