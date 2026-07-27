import Testing
@testable import Engine2

struct RealtimeAssemblyTests {
    @Test func lifecycleStartsAndStopsTheOwnedRuntimes() async {
        let assembly = RealtimeConfiguration(
            pollInterval: .seconds(60),
            catchUpPolicy: .interactive
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

    @Test func lifecycleIsIdempotent() async {
        let assembly = RealtimeConfiguration(
            pollInterval: .seconds(60),
            catchUpPolicy: .interactive
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

    @Test func userPauseSurvivesAppLifecycleAndLeavesInputLive() async {
        let assembly = RealtimeConfiguration(
            pollInterval: .seconds(60),
            catchUpPolicy: .interactive
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

    @Test func rebuildCoordinatesSessionCursorAndDriverLifecycle() async {
        let assembly = RealtimeConfiguration(
            pollInterval: .seconds(60),
            catchUpPolicy: .interactive
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

    @Test func pausedInputPublishesWithoutBypassingSimulation() async {
        let assembly = RealtimeConfiguration(
            pollInterval: .seconds(60),
            catchUpPolicy: .interactive
        ).makeAssembly(gameContent: BasicGameContent())

        // Disable advancement before activation so no cadence request can race
        // the invariant this test is proving.
        assembly.pauseAdvancement()
        assembly.start()

        let presentation = assembly.simulationRuntime.latestPresentationSnapshot
        let cursor = assembly.simulationRuntime.currentCursor
        let inputRevision = assembly.inputRuntime.latestInputSnapshot.revision
        let hostSink: any PInputEventSink = assembly.inputRuntime
        let heldKey = KeyboardKey(keyCode: 13, displayName: "W")

        let pointerDelta = SIMD2<Float>(50, 0)
        hostSink.receive(
            .mouseDragged(
                delta: pointerDelta,
                position: SIMD2<Float>(10, 20)
            )
        )
        let scrollDelta = SIMD2<Float>(0, 25)
        hostSink.receive(.scroll(delta: scrollDelta))
        hostSink.receive(.keyDown(heldKey))

        #expect(assembly.simulationRuntime.currentCursor == cursor)
        #expect(assembly.simulationRuntime.latestPresentationSnapshot == presentation)
        #expect(
            assembly.inputRuntime.latestInputSnapshot.revision != inputRevision
        )
        #expect(
            assembly.inputRuntime.latestInputSnapshot.pressedKeys == [heldKey]
        )
        #expect(
            assembly.inputRuntime.latestInputSnapshot.pointerMotionTotal ==
            pointerDelta
        )
        #expect(
            assembly.inputRuntime.latestInputSnapshot.scrollTotal
                == scrollDelta
        )

        let pausedFrame = RenderFrame(
            projecting: assembly.simulationRuntime.latestPresentationSnapshot
        )
        assembly.resumeAdvancement()
        let resumedFrame = RenderFrame(
            projecting: assembly.simulationRuntime.latestPresentationSnapshot
        )

        #expect(resumedFrame == pausedFrame)
        #expect(resumedFrame.camera == presentation.camera)
        #expect(resumedFrame.viewpointID == nil)
        #expect(resumedFrame.viewpointRevision == nil)

        await assembly.stop()
    }
}
