import Testing
@testable import Engine2

struct InputRuntimeTests {
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

    @Test func buttonAndKeyTransitionsPublishHeldState() {
        let runtime = InputRuntime()
        let key = KeyboardKey(keyCode: 49, displayName: "Space")
        runtime.start()

        runtime.receive(.mouseButtonDown(.left, position: SIMD2<Float>(3, 4)))
        let otherButtonPosition = SIMD2<Float>(5, 6)
        runtime.receive(.mouseButtonDown(.other(4), position: otherButtonPosition))
        runtime.receive(.keyDown(key))

        #expect(runtime.latestInputSnapshot.pointerPosition == otherButtonPosition)
        #expect(runtime.latestInputSnapshot.pressedMouseButtons == [.left, .other(4)])
        #expect(runtime.latestInputSnapshot.pressedKeys == [key])

        let releasedButtonPosition = SIMD2<Float>(7, 8)
        runtime.receive(.mouseButtonUp(.left, position: releasedButtonPosition))
        runtime.receive(.keyUp(key))

        #expect(runtime.latestInputSnapshot.pointerPosition == releasedButtonPosition)
        #expect(runtime.latestInputSnapshot.pressedMouseButtons == [.other(4)])
        #expect(runtime.latestInputSnapshot.pressedKeys.isEmpty)
    }

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

    @Test func instancesPublishIndependentInputState() {
        let firstRuntime = InputRuntime()
        let secondRuntime = InputRuntime()
        let key = KeyboardKey(keyCode: 13, displayName: "W")
        firstRuntime.start()
        secondRuntime.start()

        firstRuntime.receive(.keyDown(key))
        let firstScrollDelta = SIMD2<Float>(1, 2)
        firstRuntime.receive(.scroll(delta: firstScrollDelta))

        #expect(firstRuntime.latestInputSnapshot.pressedKeys == [key])
        #expect(firstRuntime.latestInputSnapshot.scrollTotal == firstScrollDelta)
        #expect(secondRuntime.latestInputSnapshot.pressedKeys.isEmpty)
        #expect(secondRuntime.latestInputSnapshot.scrollTotal == .zero)

        secondRuntime.receive(.mouseButtonDown(.right, position: SIMD2<Float>(3, 4)))

        #expect(firstRuntime.latestInputSnapshot.pressedMouseButtons.isEmpty)
        #expect(secondRuntime.latestInputSnapshot.pressedMouseButtons == [.right])
    }

    @Test func duplicateHeldStateTransitionsRemainSetLikeButStillPublish() {
        let runtime = InputRuntime()
        runtime.start()

        runtime.receive(.mouseButtonDown(.left, position: SIMD2<Float>(1, 1)))
        let secondPosition = SIMD2<Float>(2, 2)
        runtime.receive(.mouseButtonDown(.left, position: secondPosition))

        #expect(runtime.latestInputSnapshot.pressedMouseButtons == [.left])
        #expect(runtime.latestInputSnapshot.pointerPosition == secondPosition)
        #expect(runtime.latestInputSnapshot.revision.sequence == 2)

        runtime.receive(.mouseButtonUp(.left, position: SIMD2<Float>(3, 3)))
        let secondReleasePosition = SIMD2<Float>(4, 4)
        runtime.receive(.mouseButtonUp(.left, position: secondReleasePosition))

        #expect(runtime.latestInputSnapshot.pressedMouseButtons.isEmpty)
        #expect(runtime.latestInputSnapshot.pointerPosition == secondReleasePosition)
        #expect(runtime.latestInputSnapshot.revision.sequence == 4)
    }

    @Test func zeroMagnitudeContinuousEventsStillProduceOrderedPublications() {
        let runtime = InputRuntime()
        runtime.start()
        let initial = runtime.latestInputSnapshot

        runtime.receive(.mouseDragged(delta: .zero, position: .zero))
        runtime.receive(.scroll(delta: .zero))

        #expect(runtime.latestInputSnapshot.pointerMotionTotal == .zero)
        #expect(runtime.latestInputSnapshot.scrollTotal == .zero)
        #expect(runtime.latestInputSnapshot.revision.sequence == initial.revision.sequence + 2)
        #expect(runtime.latestInputSnapshot != initial)
    }

    @Test func invalidAndOverflowingPointerValuesAreIgnoredAtomically() {
        let runtime = InputRuntime()
        runtime.start()
        let initial = runtime.latestInputSnapshot

        let invalidDragDelta = SIMD2<Float>(.nan, 1)
        runtime.receive(
            .mouseDragged(
                delta: invalidDragDelta,
                position: .zero
            )
        )
        let invalidDragPosition = SIMD2<Float>(.infinity, 0)
        runtime.receive(
            .mouseDragged(
                delta: SIMD2<Float>(1, 1),
                position: invalidDragPosition
            )
        )
        let invalidButtonPosition = SIMD2<Float>(0, -.infinity)
        runtime.receive(
            .mouseButtonDown(
                .left,
                position: invalidButtonPosition
            )
        )
        let invalidScrollDelta = SIMD2<Float>(0, .infinity)
        runtime.receive(.scroll(delta: invalidScrollDelta))

        #expect(runtime.latestInputSnapshot == initial)

        let largestFinitePointerDelta = SIMD2<Float>(
            .greatestFiniteMagnitude,
            0
        )
        let firstLargestFinitePointerPosition = SIMD2<Float>(2, 3)
        runtime.receive(
            .mouseDragged(
                delta: largestFinitePointerDelta,
                position: firstLargestFinitePointerPosition
            )
        )
        let largestFinitePointerPublication = runtime.latestInputSnapshot
        runtime.receive(
            .mouseDragged(
                delta: largestFinitePointerDelta,
                position: SIMD2<Float>(4, 5)
            )
        )

        #expect(
            runtime.latestInputSnapshot ==
            largestFinitePointerPublication
        )
        #expect(
            runtime.latestInputSnapshot.pointerPosition ==
            firstLargestFinitePointerPosition
        )

        let largestFiniteScrollDelta = SIMD2<Float>(
            0,
            .greatestFiniteMagnitude
        )
        runtime.receive(
            .scroll(
                delta: largestFiniteScrollDelta
            )
        )
        let largestFiniteScrollPublication = runtime.latestInputSnapshot
        runtime.receive(
            .scroll(
                delta: largestFiniteScrollDelta
            )
        )

        #expect(
            runtime.latestInputSnapshot ==
            largestFiniteScrollPublication
        )
    }
}
