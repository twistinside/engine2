import Foundation
import Testing
@testable import Engine2

struct ManualConfigurationTests {
    @Test @MainActor func constructionCreatesAnIdleSimulationWithoutInputRuntime() {
        let sessionID = SimulationSessionID(
            rawValue: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
        )
        let assembly = ManualConfiguration().makeAssembly(
            gameContent: BasicGameContent(),
            sessionID: sessionID
        )

        #expect(assembly.simulationRuntime.currentCursor.sessionID == sessionID)
        #expect(assembly.simulationRuntime.currentCursor.tick == .zero)
        #expect(SimulationRuntime.fixedTimeStep == .seconds(1.0 / 60.0))
        #expect(assembly.presentationSource.latestPresentationSnapshot.cursor == assembly.simulationRuntime.currentCursor)
    }

    @Test @MainActor func exactCallerAloneDeterminesProgress() async throws {
        let assembly = ManualConfiguration().makeAssembly(
            gameContent: BasicGameContent()
        )
        let initialCursor = assembly.simulationRuntime.currentCursor

        await Task.yield()
        #expect(assembly.simulationRuntime.currentCursor == initialCursor)

        let outcome = await assembly.advanceTarget.advance(
            SimulationAdvanceRequest(
                expectedCursor: initialCursor,
                stepCount: SimulationStepCount(rawValue: 4)
            )
        )
        guard case let .completed(result) = outcome else {
            Issue.record("Expected a completed manual advance")
            return
        }

        #expect(result.initialCursor == initialCursor)
        #expect(result.finalCursor.tick == SimulationTick(rawValue: 4))
        #expect(result.completedStepCount.rawValue == 4)
        #expect(result.finalPresentationSnapshot.cursor == result.finalCursor)
        #expect(assembly.simulationRuntime.latestPresentationSnapshot == result.finalPresentationSnapshot)
        await Task.yield()
        #expect(assembly.simulationRuntime.currentCursor == result.finalCursor)
    }

    @Test @MainActor func tenThousandTicksMutateECSAndPublishTheExactFinalPresentation() async throws {
        let assembly = ManualConfiguration().makeAssembly(
            gameContent: BasicGameContent(
                worldBuilder: ManualMovingWorldBuilder()
            )
        )
        let initialCursor = assembly.simulationRuntime.currentCursor
        let stepCount = SimulationStepCount(rawValue: 10_000)

        let outcome = await assembly.advanceTarget.advance(
            SimulationAdvanceRequest(
                expectedCursor: initialCursor,
                stepCount: stepCount
            )
        )
        guard case let .completed(result) = outcome else {
            Issue.record("Expected the large manual advance to complete")
            return
        }
        let entity = try #require(
            assembly.simulationRuntime.world.positionComponents.entities.first
        )
        let worldPosition = try #require(
            assembly.simulationRuntime.world.positionComponents[entity]?.position
        )
        let presentation = try #require(
            result.finalPresentationSnapshot.entityPresentations.first {
                $0.id == entity
            }
        )

        #expect(result.initialCursor == initialCursor)
        #expect(result.completedStepCount.rawValue == 10_000)
        #expect(result.finalCursor.tick == SimulationTick(rawValue: 10_000))
        #expect(result.finalPresentationSnapshot.cursor == result.finalCursor)
        #expect(presentation.position == worldPosition)
        #expect(abs(worldPosition.x - 10_000) < 1)
        #expect(worldPosition.y == 0)
        #expect(worldPosition.z == 0)
    }

    @Test @MainActor func assembliesOwnIndependentSessionsAndWorlds() {
        let configuration = ManualConfiguration()
        let first = configuration.makeAssembly(gameContent: BasicGameContent())
        let second = configuration.makeAssembly(gameContent: BasicGameContent())

        #expect(first !== second)
        #expect(first.simulationRuntime !== second.simulationRuntime)
        #expect(first.simulationRuntime.world !== second.simulationRuntime.world)
        #expect(first.simulationRuntime.sessionID != second.simulationRuntime.sessionID)
    }
}

private struct ManualMovingWorldBuilder: PWorldBuilder {
    func buildWorld() -> World {
        let world = World()
        _ = Ball(
            in: world,
            position: .zero,
            velocity: SIMD3<Float>(
                1 / SimulationRuntime.fixedTimeStep.seconds,
                0,
                0
            )
        )
        return world
    }
}
