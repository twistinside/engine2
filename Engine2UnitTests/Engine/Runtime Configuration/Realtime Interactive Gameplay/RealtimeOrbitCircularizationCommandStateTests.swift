import Testing
@testable import Engine2

struct RealtimeOrbitCircularizationCommandStateTests {
    @Test func completionRetiresTheExactCommandGenerationItObserved() {
        var state = RealtimeOrbitCircularizationCommandState()
        state.stage(command(for: 1))
        let requestState = state

        state.retire(ifUnchangedSince: requestState)

        #expect(state.command == nil)
    }

    @Test func newerCommandSurvivesStaleCompletionBookkeeping() {
        var state = RealtimeOrbitCircularizationCommandState()
        state.stage(command(for: 1))
        let staleRequestState = state
        state.stage(command(for: 2))

        state.retire(ifUnchangedSince: staleRequestState)

        #expect(state.command == command(for: 2))
    }

    @Test func explicitClearDiscardsThePendingCommand() {
        var state = RealtimeOrbitCircularizationCommandState()
        state.stage(command(for: 1))

        state.clear()

        #expect(state.command == nil)
    }

    private func command(for index: Int) -> OrbitCircularizationCommand {
        OrbitCircularizationCommand(
            entityID: EntityID(index: index, generation: 0)
        )
    }
}
