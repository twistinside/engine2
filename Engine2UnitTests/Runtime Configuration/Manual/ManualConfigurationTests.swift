import Foundation
import Testing
@testable import Engine2

struct ManualConfigurationTests {
    @Test func constructionCreatesAnIdleSimulationWithoutInputRuntime() {
        let sessionUUID = UUID(
            uuidString: "20000000-0000-0000-0000-000000000001"
        )!
        let sessionID = SimulationSessionID(rawValue: sessionUUID)
        let gameContent = BasicGameContent()
        let assembly = ManualConfiguration().makeAssembly(
            gameContent: gameContent,
            sessionID: sessionID
        )

        #expect(assembly.simulationRuntime.currentCursor.sessionID == sessionID)
        #expect(assembly.simulationRuntime.currentCursor.tick == .zero)
        #expect(SimulationRuntime.fixedTimeStep == .seconds(1.0 / 60.0))
        #expect(assembly.presentationSource.latestPresentationSnapshot.cursor == assembly.simulationRuntime.currentCursor)
    }

    @Test func exactCallerAloneDeterminesProgress() async throws {
        let gameContent = BasicGameContent()
        let assembly = ManualConfiguration().makeAssembly(
            gameContent: gameContent
        )
        let initialCursor = assembly.simulationRuntime.currentCursor

        await Task.yield()
        #expect(assembly.simulationRuntime.currentCursor == initialCursor)

        let stepCount = SimulationStepCount(rawValue: 4)
        let request = SimulationAdvanceRequest(
            expectedCursor: initialCursor,
            stepCount: stepCount,
            inputAssignment: .none
        )
        let outcome = await assembly.advanceTarget.advance(request)
        guard case let .completed(result) = outcome else {
            Issue.record("Expected a completed manual advance")
            return
        }

        #expect(result.initialCursor == initialCursor)
        let expectedFinalTick = SimulationTick(rawValue: 4)
        #expect(result.finalCursor.tick == expectedFinalTick)
        #expect(result.completedStepCount.rawValue == 4)
        #expect(result.finalPresentationSnapshot.cursor == result.finalCursor)
        #expect(assembly.simulationRuntime.latestPresentationSnapshot == result.finalPresentationSnapshot)
        await Task.yield()
        #expect(assembly.simulationRuntime.currentCursor == result.finalCursor)
    }

    @Test func tenThousandTicksMutateECSAndPublishTheExactFinalPresentation() async throws {
        let worldBuilder = ManualMovingWorldBuilder()
        let gameContent = BasicGameContent(worldBuilder: worldBuilder)
        let assembly = ManualConfiguration().makeAssembly(
            gameContent: gameContent
        )
        let initialCursor = assembly.simulationRuntime.currentCursor
        let stepCount = SimulationStepCount(rawValue: 10_000)

        let request = SimulationAdvanceRequest(
            expectedCursor: initialCursor,
            stepCount: stepCount,
            inputAssignment: .none
        )
        let outcome = await assembly.advanceTarget.advance(request)
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
        let expectedFinalTick = SimulationTick(rawValue: 10_000)
        #expect(result.finalCursor.tick == expectedFinalTick)
        #expect(result.finalPresentationSnapshot.cursor == result.finalCursor)
        #expect(presentation.position == worldPosition)
        #expect(abs(worldPosition.x - 10_000) < 1)
        #expect(worldPosition.y == 0)
        #expect(worldPosition.z == 0)
    }

    @Test func assembliesOwnIndependentSessionsAndWorlds() {
        let configuration = ManualConfiguration()
        let firstContent = BasicGameContent()
        let first = configuration.makeAssembly(gameContent: firstContent)
        let secondContent = BasicGameContent()
        let second = configuration.makeAssembly(gameContent: secondContent)

        #expect(first !== second)
        #expect(first.simulationRuntime !== second.simulationRuntime)
        #expect(first.simulationRuntime.world !== second.simulationRuntime.world)
        #expect(first.simulationRuntime.sessionID != second.simulationRuntime.sessionID)
    }
}

private extension ManualConfigurationTests {
    private struct ManualMovingWorldBuilder: PWorldBuilder {
        func buildWorld() -> World {
            let world = World()
            let velocity = SIMD3<Float>(
                1 / SimulationRuntime.fixedTimeStep.seconds,
                0,
                0
            )
            _ = Ball(
                in: world,
                materialID: .warmDielectric,
                position: .zero,
                velocity: velocity
            )
            return world
        }
    }
}
