import Testing
@testable import Engine2

struct InputRuntimeTests {
    @MainActor
    @Test func diagnosticsSampleContinuousIngressButPublishEverySnapshot() throws {
        let sink = RecordingDiagnosticsSink()
        let diagnostics = DiagnosticsEmitter(sink: sink)
        let runtime = InputRuntime(
            diagnostics: diagnostics,
            continuousEventDiagnosticsStride: 2
        )
        let key = KeyboardKey(keyCode: 13, displayName: "W")
        runtime.start()
        runtime.receive(.mouseDragged(delta: SIMD2<Float>(1, 0), position: .zero))
        runtime.receive(.mouseDragged(delta: SIMD2<Float>(1, 0), position: .zero))
        runtime.receive(.mouseDragged(delta: SIMD2<Float>(1, 0), position: .zero))
        runtime.receive(.keyDown(key))

        let receiveFacts = sink.samples.compactMap { sample -> InputReceiveDiagnostics? in
            guard case let .inputReceive(payload) = sample.payload else {
                return nil
            }
            return payload
        }
        let snapshotFacts = sink.samples.compactMap { sample -> InputSnapshotDiagnostics? in
            guard case let .inputSnapshot(payload) = sample.payload else {
                return nil
            }
            return payload
        }

        #expect(receiveFacts.map(\.eventID) == [.mouseDragged, .mouseDragged, .keyDown])
        #expect(receiveFacts.map(\.revision.sequence) == [1, 3, 4])
        #expect(snapshotFacts.map(\.revision.sequence) == [0, 1, 2, 3, 4])
        let latestFact = try #require(snapshotFacts.last)
        #expect(latestFact.heldKeyCount == 1)
        #expect(latestFact.heldMouseButtonCount == 0)
        #expect(runtime.latestInputSnapshot.pointerMotionTotal == SIMD2<Float>(3, 0))
        #expect(runtime.latestInputSnapshot.pressedKeys == [key])
    }

    @MainActor
    @Test func lifecyclePublishesFreshIdempotentSessions() {
        let runtime = InputRuntime()

        #expect(runtime.isRunning == false)
        #expect(runtime.latestInputSnapshot == .empty)

        runtime.start()
        let firstSession = runtime.latestInputSnapshot

        #expect(runtime.isRunning)
        #expect(firstSession.revision == InputRevision(session: 1, sequence: 0))
        #expect(firstSession.pointerPosition == .zero)
        #expect(firstSession.pointerMotionTotal == .zero)
        #expect(firstSession.scrollTotal == .zero)
        #expect(firstSession.pressedMouseButtons.isEmpty)
        #expect(firstSession.pressedKeys.isEmpty)

        runtime.start()
        #expect(runtime.latestInputSnapshot == firstSession)

        runtime.stop()
        let stoppedSession = runtime.latestInputSnapshot
        runtime.stop()

        #expect(runtime.isRunning == false)
        #expect(runtime.latestInputSnapshot == stoppedSession)

        runtime.start()

        #expect(runtime.latestInputSnapshot.revision == InputRevision(session: 2, sequence: 0))
        #expect(runtime.latestInputSnapshot.pointerPosition == .zero)
        #expect(runtime.latestInputSnapshot.pointerMotionTotal == .zero)
        #expect(runtime.latestInputSnapshot.scrollTotal == .zero)
    }

    @MainActor
    @Test func priorSnapshotsRemainImmutableAsNewEventsArrive() {
        let runtime = InputRuntime()
        let key = KeyboardKey(keyCode: 13, displayName: "W")
        runtime.start()

        let neutralSnapshot = runtime.latestInputSnapshot
        runtime.receive(.keyDown(key))
        let heldSnapshot = runtime.latestInputSnapshot
        runtime.receive(.keyUp(key))

        #expect(neutralSnapshot.pressedKeys.isEmpty)
        #expect(neutralSnapshot.revision == InputRevision(session: 1, sequence: 0))
        #expect(heldSnapshot.pressedKeys == [key])
        #expect(heldSnapshot.revision == InputRevision(session: 1, sequence: 1))
        #expect(runtime.latestInputSnapshot.pressedKeys.isEmpty)
        #expect(runtime.latestInputSnapshot.revision == InputRevision(session: 1, sequence: 2))
    }

    @MainActor
    @Test func pointerAndScrollTotalsAccumulateAcrossPublications() {
        let runtime = InputRuntime()
        runtime.start()

        runtime.receive(
            .mouseDragged(
                delta: SIMD2<Float>(1.5, -2),
                position: SIMD2<Float>(10, 20)
            )
        )
        runtime.receive(
            .mouseDragged(
                delta: SIMD2<Float>(-0.5, 5),
                position: SIMD2<Float>(11, 25)
            )
        )
        runtime.receive(.scroll(delta: SIMD2<Float>(4, -3)))
        runtime.receive(.scroll(delta: SIMD2<Float>(-1, 0.5)))

        let snapshot = runtime.latestInputSnapshot
        #expect(snapshot.pointerPosition == SIMD2<Float>(11, 25))
        #expect(snapshot.pointerMotionTotal == SIMD2<Float>(1, 3))
        #expect(snapshot.scrollTotal == SIMD2<Float>(3, -2.5))
        #expect(snapshot.revision == InputRevision(session: 1, sequence: 4))
    }

    @MainActor
    @Test func buttonAndKeyTransitionsPublishHeldState() {
        let runtime = InputRuntime()
        let key = KeyboardKey(keyCode: 49, displayName: "Space")
        runtime.start()

        runtime.receive(.mouseButtonDown(.left, position: SIMD2<Float>(3, 4)))
        runtime.receive(.mouseButtonDown(.other(4), position: SIMD2<Float>(5, 6)))
        runtime.receive(.keyDown(key))

        #expect(runtime.latestInputSnapshot.pointerPosition == SIMD2<Float>(5, 6))
        #expect(runtime.latestInputSnapshot.pressedMouseButtons == [.left, .other(4)])
        #expect(runtime.latestInputSnapshot.pressedKeys == [key])

        runtime.receive(.mouseButtonUp(.left, position: SIMD2<Float>(7, 8)))
        runtime.receive(.keyUp(key))

        #expect(runtime.latestInputSnapshot.pointerPosition == SIMD2<Float>(7, 8))
        #expect(runtime.latestInputSnapshot.pressedMouseButtons == [.other(4)])
        #expect(runtime.latestInputSnapshot.pressedKeys.isEmpty)
    }

    @MainActor
    @Test func stopPublishesNeutralHeldStateWithoutDiscardingSessionTotals() {
        let runtime = InputRuntime()
        let key = KeyboardKey(keyCode: 13, displayName: "W")
        runtime.start()
        runtime.receive(.mouseButtonDown(.right, position: SIMD2<Float>(8, 9)))
        runtime.receive(.keyDown(key))
        runtime.receive(
            .mouseDragged(
                delta: SIMD2<Float>(2, 3),
                position: SIMD2<Float>(10, 12)
            )
        )
        runtime.receive(.scroll(delta: SIMD2<Float>(0, -4)))
        let activeSnapshot = runtime.latestInputSnapshot

        runtime.stop()

        let stoppedSnapshot = runtime.latestInputSnapshot
        #expect(runtime.isRunning == false)
        #expect(stoppedSnapshot.revision == InputRevision(session: 1, sequence: 5))
        #expect(stoppedSnapshot.pressedMouseButtons.isEmpty)
        #expect(stoppedSnapshot.pressedKeys.isEmpty)
        #expect(stoppedSnapshot.pointerPosition == activeSnapshot.pointerPosition)
        #expect(stoppedSnapshot.pointerMotionTotal == activeSnapshot.pointerMotionTotal)
        #expect(stoppedSnapshot.scrollTotal == activeSnapshot.scrollTotal)
    }

    @MainActor
    @Test func eventsAreIgnoredWhileStopped() {
        let runtime = InputRuntime()
        let key = KeyboardKey(keyCode: 13, displayName: "W")

        runtime.receive(.keyDown(key))
        runtime.receive(.scroll(delta: SIMD2<Float>(1, 2)))
        #expect(runtime.latestInputSnapshot == .empty)

        runtime.start()
        runtime.stop()
        let stoppedSnapshot = runtime.latestInputSnapshot

        runtime.receive(.mouseButtonDown(.left, position: SIMD2<Float>(2, 3)))
        runtime.receive(
            .mouseDragged(
                delta: SIMD2<Float>(4, 5),
                position: SIMD2<Float>(6, 7)
            )
        )

        #expect(runtime.latestInputSnapshot == stoppedSnapshot)
    }

    @MainActor
    @Test func instancesPublishIndependentInputState() {
        let firstRuntime = InputRuntime()
        let secondRuntime = InputRuntime()
        let key = KeyboardKey(keyCode: 13, displayName: "W")
        firstRuntime.start()
        secondRuntime.start()

        firstRuntime.receive(.keyDown(key))
        firstRuntime.receive(.scroll(delta: SIMD2<Float>(1, 2)))

        #expect(firstRuntime.latestInputSnapshot.pressedKeys == [key])
        #expect(firstRuntime.latestInputSnapshot.scrollTotal == SIMD2<Float>(1, 2))
        #expect(secondRuntime.latestInputSnapshot.pressedKeys.isEmpty)
        #expect(secondRuntime.latestInputSnapshot.scrollTotal == .zero)

        secondRuntime.receive(.mouseButtonDown(.right, position: SIMD2<Float>(3, 4)))

        #expect(firstRuntime.latestInputSnapshot.pressedMouseButtons.isEmpty)
        #expect(secondRuntime.latestInputSnapshot.pressedMouseButtons == [.right])
    }
}
