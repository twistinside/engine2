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
        #expect(firstSession.translation == .zero)
        #expect(firstSession.isInteractionActive == false)
        #expect(firstSession.cameraOrbitTotal == .zero)
        #expect(firstSession.cameraZoomTotal == 0)
        #expect(firstSession.latestSelectionPress == nil)
        #expect(firstSession.selectionPressCount == 0)

        runtime.start()
        #expect(runtime.latestInputSnapshot == firstSession)

        runtime.stop()
        let stoppedSession = runtime.latestInputSnapshot
        runtime.stop()

        #expect(runtime.isRunning == false)
        #expect(runtime.latestInputSnapshot == stoppedSession)

        runtime.start()
        #expect(runtime.latestInputSnapshot == InputSnapshot(
            revision: InputRevision(session: 2, sequence: 0),
            translation: .zero,
            isInteractionActive: false,
            cameraOrbitTotal: .zero,
            cameraZoomTotal: 0,
            latestSelectionPress: nil,
            selectionPressCount: 0
        ))
    }

    @Test func standardAliasesDeduplicateAndOppositeDirectionsCancel() {
        let runtime = InputRuntime()
        runtime.start()

        runtime.receive(.keyDown(KeyboardKey(keyCode: 13)))
        runtime.receive(.keyDown(KeyboardKey(keyCode: 126)))
        #expect(runtime.latestInputSnapshot.translation == SIMD2<Float>(0, 1))

        runtime.receive(.keyDown(KeyboardKey(keyCode: 1)))
        #expect(runtime.latestInputSnapshot.translation == .zero)

        runtime.receive(.keyUp(KeyboardKey(keyCode: 13)))
        #expect(runtime.latestInputSnapshot.translation == .zero)

        runtime.receive(.keyUp(KeyboardKey(keyCode: 126)))
        #expect(runtime.latestInputSnapshot.translation == SIMD2<Float>(0, -1))
    }

    @Test func diagonalTranslationIsNormalizedAndReleasesRemainSemantic() {
        let runtime = InputRuntime()
        runtime.start()

        runtime.receive(.keyDown(KeyboardKey(keyCode: 13)))
        runtime.receive(.keyDown(KeyboardKey(keyCode: 2)))

        let translation = runtime.latestInputSnapshot.translation
        let expectedComponent = Float(1 / Double(2).squareRoot())
        #expect(abs(translation.x - expectedComponent) < 0.0001)
        #expect(abs(translation.y - expectedComponent) < 0.0001)

        runtime.receive(.keyUp(KeyboardKey(keyCode: 2)))
        #expect(runtime.latestInputSnapshot.translation == SIMD2<Float>(0, 1))
    }

    @Test func spacePublishesHeldInteractionState() {
        let runtime = InputRuntime()
        runtime.start()

        runtime.receive(.keyDown(KeyboardKey(keyCode: 49)))
        #expect(runtime.latestInputSnapshot.isInteractionActive)

        runtime.receive(.keyUp(KeyboardKey(keyCode: 49)))
        #expect(runtime.latestInputSnapshot.isInteractionActive == false)
    }

    @Test func focusLossClearsEveryHeldSemanticWithoutStoppingTheRuntime() {
        let runtime = InputRuntime()
        runtime.start()
        runtime.receive(.keyDown(KeyboardKey(keyCode: 13)))
        runtime.receive(.keyDown(KeyboardKey(keyCode: 49)))

        runtime.receive(.focusLost)

        #expect(runtime.isRunning)
        #expect(runtime.latestInputSnapshot.translation == .zero)
        #expect(runtime.latestInputSnapshot.isInteractionActive == false)
    }

    @Test func focusLossWithoutHeldKeyStateDoesNotPublish() {
        let runtime = InputRuntime()
        runtime.start()
        runtime.receive(
            .mouseButtonDown(
                .right,
                position: SIMD2<Float>(25, 10),
                viewportSize: SIMD2<Float>(100, 50)
            )
        )
        let mouseSnapshot = runtime.latestInputSnapshot

        runtime.receive(.focusLost)

        #expect(runtime.latestInputSnapshot == mouseSnapshot)
    }

    @Test func customConfigurationMapsCameraTotalsBeforePublication() {
        let runtime = InputRuntime(
            mappingConfiguration: configuration(
                pointerOrbitSensitivity: 0.5,
                scrollZoomSensitivity: 2
            )
        )
        runtime.start()

        runtime.receive(
            .mouseDragged(
                delta: SIMD2<Float>(4, -6),
                position: SIMD2<Float>(10, 20),
                viewportSize: SIMD2<Float>(100, 50)
            )
        )
        runtime.receive(.scroll(delta: SIMD2<Float>(99, -3)))

        #expect(runtime.latestInputSnapshot.cameraOrbitTotal == SIMD2<Float>(2, -3))
        #expect(runtime.latestInputSnapshot.cameraZoomTotal == -6)
    }

    @Test func primaryPressPublishesNormalizedSelectionAndLatestPressWins() throws {
        let runtime = InputRuntime()
        runtime.start()

        runtime.receive(
            .mouseButtonDown(
                .left,
                position: SIMD2<Float>(25, 10),
                viewportSize: SIMD2<Float>(100, 50)
            )
        )
        runtime.receive(
            .mouseButtonDown(
                .left,
                position: SIMD2<Float>(90, 40),
                viewportSize: SIMD2<Float>(100, 50)
            )
        )

        let selection = try #require(runtime.latestInputSnapshot.latestSelectionPress)
        #expect(selection.normalizedPosition == SIMD2<Float>(0.9, 0.8))
        #expect(selection.aspectRatio == 2)
        #expect(runtime.latestInputSnapshot.selectionPressCount == 2)
    }

    @Test func nonselectionButtonDoesNotPublishSelectionIntent() {
        let runtime = InputRuntime()
        runtime.start()

        runtime.receive(
            .mouseButtonDown(
                .right,
                position: SIMD2<Float>(25, 10),
                viewportSize: SIMD2<Float>(100, 50)
            )
        )

        #expect(runtime.latestInputSnapshot.latestSelectionPress == nil)
        #expect(runtime.latestInputSnapshot.selectionPressCount == 0)
    }

    @Test func stopClearsHeldIntentWithoutDiscardingSessionTotals() {
        let runtime = InputRuntime()
        runtime.start()
        runtime.receive(.keyDown(KeyboardKey(keyCode: 13)))
        runtime.receive(.keyDown(KeyboardKey(keyCode: 49)))
        runtime.receive(
            .mouseDragged(
                delta: SIMD2<Float>(2, 3),
                position: SIMD2<Float>(10, 12),
                viewportSize: SIMD2<Float>(100, 50)
            )
        )
        runtime.receive(.scroll(delta: SIMD2<Float>(0, -4)))
        let activeSnapshot = runtime.latestInputSnapshot

        runtime.stop()

        let stoppedSnapshot = runtime.latestInputSnapshot
        #expect(stoppedSnapshot.translation == .zero)
        #expect(stoppedSnapshot.isInteractionActive == false)
        #expect(stoppedSnapshot.cameraOrbitTotal == activeSnapshot.cameraOrbitTotal)
        #expect(stoppedSnapshot.cameraZoomTotal == activeSnapshot.cameraZoomTotal)
    }

    @Test func eventsAreIgnoredWhileStopped() {
        let runtime = InputRuntime()

        runtime.receive(.keyDown(KeyboardKey(keyCode: 13)))
        runtime.receive(.scroll(delta: SIMD2<Float>(1, 2)))
        #expect(runtime.latestInputSnapshot == .empty)

        runtime.start()
        runtime.stop()
        let stoppedSnapshot = runtime.latestInputSnapshot
        runtime.receive(.keyDown(KeyboardKey(keyCode: 49)))

        #expect(runtime.latestInputSnapshot == stoppedSnapshot)
    }

    @Test func invalidAndOverflowingContinuousEventsAreIgnoredAtomically() {
        let runtime = InputRuntime(
            mappingConfiguration: configuration(
                pointerOrbitSensitivity: 1,
                scrollZoomSensitivity: 1
            )
        )
        runtime.start()
        let initial = runtime.latestInputSnapshot

        runtime.receive(
            .mouseDragged(
                delta: SIMD2<Float>(.nan, 1),
                position: .zero,
                viewportSize: SIMD2<Float>(100, 50)
            )
        )
        runtime.receive(
            .mouseButtonDown(
                .left,
                position: .zero,
                viewportSize: SIMD2<Float>(100, 0)
            )
        )
        runtime.receive(.scroll(delta: SIMD2<Float>(0, .infinity)))
        #expect(runtime.latestInputSnapshot == initial)

        runtime.receive(
            .mouseDragged(
                delta: SIMD2<Float>(.greatestFiniteMagnitude, 0),
                position: .zero,
                viewportSize: SIMD2<Float>(100, 50)
            )
        )
        let largestDrag = runtime.latestInputSnapshot
        runtime.receive(
            .mouseDragged(
                delta: SIMD2<Float>(.greatestFiniteMagnitude, 0),
                position: SIMD2<Float>(1, 1),
                viewportSize: SIMD2<Float>(100, 50)
            )
        )
        #expect(runtime.latestInputSnapshot == largestDrag)

        runtime.receive(.scroll(delta: SIMD2<Float>(0, .greatestFiniteMagnitude)))
        let largestScroll = runtime.latestInputSnapshot
        runtime.receive(.scroll(delta: SIMD2<Float>(0, .greatestFiniteMagnitude)))
        #expect(runtime.latestInputSnapshot == largestScroll)
    }

    private func configuration(
        pointerOrbitSensitivity: Float,
        scrollZoomSensitivity: Float
    ) -> InputMappingConfiguration {
        InputMappingConfiguration(
            leftKeyCodes: [0, 123],
            rightKeyCodes: [2, 124],
            upwardKeyCodes: [13, 126],
            downwardKeyCodes: [1, 125],
            interactionKeyCodes: [49],
            selectionButton: .left,
            pointerOrbitSensitivity: pointerOrbitSensitivity,
            scrollZoomSensitivity: scrollZoomSensitivity
        )
    }
}
