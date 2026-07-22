import Foundation
import Testing
@testable import Engine2

struct ManualConfigurationTests {
    @Test @MainActor func constructionCreatesAnIdleSimulationWithoutInputRuntime() {
        let sessionID = SimulationSessionID(
            rawValue: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
        )
        let assembly = ManualConfiguration(
            fixedTimeStep: .milliseconds(25)
        ).makeAssembly(
            gameContent: BasicGameContent(),
            sessionID: sessionID
        )

        #expect(assembly.simulationRuntime.currentCursor.sessionID == sessionID)
        #expect(assembly.simulationRuntime.currentCursor.tick == .zero)
        #expect(assembly.simulationRuntime.state.fixedTimeStep == .milliseconds(25))
        #expect(assembly.simulationRuntime.state.isLoopRunning == false)
        #expect(assembly.simulationRuntime.state.isRunning == false)
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
        #expect(assembly.simulationRuntime.state.isLoopRunning == false)
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
