import Testing
@testable import Engine2

struct RealtimeAssemblyTests {
    @Test @MainActor func lifecycleStartsAndStopsTheOwnedRuntimes() async {
        let assembly = RealtimeConfiguration(
            pollInterval: .seconds(60)
        ).makeAssembly(gameContent: BasicGameContent())

        assembly.start()

        #expect(assembly.inputRuntime.isRunning)
        #expect(assembly.advanceDriver.isRunning)
        #expect(assembly.advanceDriver.isAdvancementEnabled)

        await assembly.stop()

        #expect(assembly.advanceDriver.isRunning == false)
        #expect(assembly.advanceDriver.isAdvancementEnabled)
        #expect(assembly.inputRuntime.isRunning == false)
    }

    @Test @MainActor func lifecycleIsIdempotent() async {
        let assembly = RealtimeConfiguration(
            pollInterval: .seconds(60)
        ).makeAssembly(gameContent: BasicGameContent())

        assembly.start()
        let startedRevision = assembly.inputRuntime.latestInputSnapshot.revision
        assembly.start()

        #expect(assembly.inputRuntime.latestInputSnapshot.revision == startedRevision)
        #expect(assembly.advanceDriver.isRunning)

        await assembly.stop()
        let stoppedRevision = assembly.inputRuntime.latestInputSnapshot.revision
        await assembly.stop()

        #expect(assembly.inputRuntime.latestInputSnapshot.revision == stoppedRevision)
        #expect(assembly.advanceDriver.isRunning == false)
    }

    @Test @MainActor func userPauseSurvivesAppLifecycleAndLeavesInputLive() async {
        let assembly = RealtimeConfiguration(
            pollInterval: .seconds(60)
        ).makeAssembly(gameContent: BasicGameContent())

        assembly.start()
        assembly.pauseAdvancement()
        let pausedCursor = assembly.simulationRuntime.currentCursor

        #expect(assembly.advanceDriver.isAdvancementEnabled == false)
        #expect(assembly.advanceDriver.isRunning)
        #expect(assembly.inputRuntime.isRunning)

        await assembly.stop()
        assembly.start()
        await Task.yield()

        #expect(assembly.advanceDriver.isAdvancementEnabled == false)
        #expect(assembly.advanceDriver.isRunning)
        #expect(assembly.inputRuntime.isRunning)
        #expect(assembly.simulationRuntime.currentCursor == pausedCursor)

        await assembly.stop()
    }

    @Test @MainActor func rebuildCoordinatesSessionCursorAndDriverLifecycle() async {
        let assembly = RealtimeConfiguration(
            pollInterval: .seconds(60)
        ).makeAssembly(gameContent: BasicGameContent())
        assembly.start()
        let initialCursor = assembly.simulationRuntime.currentCursor

        await assembly.rebuildSimulation()

        #expect(assembly.simulationRuntime.currentCursor.sessionID != initialCursor.sessionID)
        #expect(assembly.simulationRuntime.currentCursor.tick == .zero)
        #expect(assembly.advanceDriver.isRunning)
        #expect(assembly.inputRuntime.isRunning)

        await assembly.stop()
    }

    @Test @MainActor func pausedInputChangesViewpointWithoutAdvancingSimulation() async {
        let assembly = RealtimeConfiguration(
            pollInterval: .seconds(60)
        ).makeAssembly(gameContent: BasicGameContent())

        // Disable advancement before activation so no cadence request can race
        // the invariant this test is proving.
        assembly.pauseAdvancement()
        assembly.start()

        let presentation = assembly.simulationRuntime.latestPresentationSnapshot
        let cursor = assembly.simulationRuntime.currentCursor
        let initialViewpoint = assembly.screenViewpointController.resolveViewpoint(
            defaultCamera: presentation.camera
        )

        assembly.receive(
            .mouseDragged(
                delta: SIMD2<Float>(50, 0),
                position: SIMD2<Float>(10, 20)
            )
        )
        assembly.receive(.scroll(delta: SIMD2<Float>(0, 25)))

        let changedViewpoint = assembly.screenViewpointController.resolveViewpoint(
            defaultCamera: presentation.camera
        )

        #expect(assembly.simulationRuntime.currentCursor == cursor)
        #expect(assembly.simulationRuntime.latestPresentationSnapshot == presentation)
        #expect(changedViewpoint.id == initialViewpoint.id)
        #expect(changedViewpoint.revision > initialViewpoint.revision)
        #expect(changedViewpoint.camera != initialViewpoint.camera)
        #expect(
            assembly.inputRuntime.latestInputSnapshot.pointerMotionTotal ==
            SIMD2<Float>(50, 0)
        )

        await assembly.stop()
    }
}
