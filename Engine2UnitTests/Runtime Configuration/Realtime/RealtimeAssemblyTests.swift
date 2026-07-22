import Testing
@testable import Engine2

struct RealtimeAssemblyTests {
    @Test @MainActor func lifecycleStartsAndStopsTheOwnedRuntimes() {
        let assembly = RealtimeConfiguration(
            pollInterval: .seconds(60)
        ).makeAssembly(gameContent: BasicGameContent())

        assembly.start()

        #expect(assembly.inputRuntime.isRunning)
        #expect(assembly.simulationRuntime.state.isRunning)
        #expect(assembly.simulationRuntime.state.isLoopRunning)

        assembly.stop()

        #expect(assembly.simulationRuntime.state.isRunning == false)
        #expect(assembly.simulationRuntime.state.isLoopRunning == false)
        #expect(assembly.inputRuntime.isRunning == false)
    }

    @Test @MainActor func lifecycleIsIdempotent() {
        let assembly = RealtimeConfiguration(
            pollInterval: .seconds(60)
        ).makeAssembly(gameContent: BasicGameContent())

        assembly.start()
        let startedRevision = assembly.inputRuntime.latestInputSnapshot.revision
        assembly.start()

        #expect(assembly.inputRuntime.latestInputSnapshot.revision == startedRevision)
        #expect(assembly.simulationRuntime.state.isLoopRunning)

        assembly.stop()
        let stoppedRevision = assembly.inputRuntime.latestInputSnapshot.revision
        assembly.stop()

        #expect(assembly.inputRuntime.latestInputSnapshot.revision == stoppedRevision)
        #expect(assembly.simulationRuntime.state.isLoopRunning == false)
    }
}
