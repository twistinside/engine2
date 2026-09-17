import Testing
@testable import Engine2

struct RealtimeAssemblyConstructionTests {
    @Test func gameContentConstructionSelectsTheApplicationPolicy() {
        let assembly = RealtimeAssembly(using: BasicGameContent())

        #expect(
            assembly.advanceDriver.pollInterval ==
            SimulationRuntime.fixedTimeStep
        )
        #expect(assembly.advanceDriver.catchUpPolicy == .interactive)
        #expect(assembly.inputRuntime.isRunning == false)
        #expect(assembly.advanceDriver.isRunning == false)
    }

    @Test func explicitConstructionUsesPolicyAndGameContent() throws {
        let catchUpPolicy = RealtimeCatchUpPolicy(
            maximumStepsPerWake: SimulationStepCount(rawValue: 2),
            backlogTreatment: .preserve
        )
        let expectedPosition = SIMD3<Double>(3, 4, 5)
        let gameContent = BasicGameContent(
            worldBuilder: RealtimeTestWorldBuilder(position: expectedPosition)
        )

        let assembly = RealtimeAssembly(
            content: gameContent,
            pollInterval: .seconds(60),
            catchUpPolicy: catchUpPolicy
        )
        let entity = try #require(
            assembly.simulationRuntime.world.components[PositionComponent.self].entities.first
        )

        #expect(assembly.advanceDriver.fixedTimeStep == SimulationRuntime.fixedTimeStep)
        #expect(assembly.advanceDriver.pollInterval == .seconds(60))
        #expect(assembly.advanceDriver.catchUpPolicy == catchUpPolicy)
        #expect(
            assembly.simulationRuntime.world.components[PositionComponent.self][entity]?.position ==
            expectedPosition
        )
        #expect(assembly.inputRuntime.isRunning == false)
        #expect(assembly.advanceDriver.isRunning == false)
        #expect(
            assembly.simulationRuntime.latestPresentationSnapshot.camera
                == assembly.simulationRuntime.world.camera
        )
    }

    @Test func assembliesOwnIsolatedRuntimeInstances() {
        let content = BasicGameContent(
            worldBuilder: RealtimeTestWorldBuilder(position: .zero)
        )

        let first = RealtimeAssembly(
            content: content,
            pollInterval: .seconds(60),
            catchUpPolicy: .interactive
        )
        let second = RealtimeAssembly(
            content: content,
            pollInterval: .seconds(60),
            catchUpPolicy: .interactive
        )

        #expect(first.inputRuntime !== second.inputRuntime)
        #expect(first.simulationRuntime !== second.simulationRuntime)
        #expect(first.advanceDriver !== second.advanceDriver)
        #expect(first.simulationRuntime.world !== second.simulationRuntime.world)
    }

    @Test func fixedStepPollingPolicyIsSelectedExplicitly() {
        let assembly = RealtimeAssembly(
            content: BasicGameContent(),
            pollInterval: SimulationRuntime.fixedTimeStep,
            catchUpPolicy: .interactive
        )

        #expect(assembly.advanceDriver.pollInterval == SimulationRuntime.fixedTimeStep)
    }
}

private extension RealtimeAssemblyConstructionTests {
    private struct RealtimeTestWorldBuilder: WorldBuilder {
        let position: SIMD3<Double>

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
