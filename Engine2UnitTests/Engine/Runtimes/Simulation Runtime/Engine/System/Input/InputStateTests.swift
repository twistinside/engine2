import Testing
@testable import Engine2

struct InputStateTests {
    @Test func initialAndNewSessionCumulativeTotalsApplyFromZero() throws {
        var input = InputState()
        let firstSelection = try #require(
            SelectionPress(
                normalizedPosition: SIMD2<Float>(0.25, 0.75),
                aspectRatio: 2
            )
        )
        input.ingest(
            snapshot(
                session: 1,
                sequence: 4,
                translation: SIMD2<Float>(1, 0),
                isInteractionActive: true,
                cameraOrbitTotal: SIMD2<Float>(3, -2),
                cameraZoomTotal: -4,
                latestSelectionPress: firstSelection,
                selectionPressCount: 2
            )
        )

        #expect(input.translation == SIMD2<Float>(1, 0))
        #expect(input.isInteractionActive)
        #expect(input.cameraOrbitDelta == SIMD2<Float>(3, -2))
        #expect(input.cameraZoomDelta == -4)
        #expect(input.selectionPress == firstSelection)

        input.clearTransientInput()
        input.ingest(
            snapshot(
                session: 2,
                sequence: 2,
                translation: SIMD2<Float>(0, -1),
                cameraOrbitTotal: SIMD2<Float>(5, 6),
                cameraZoomTotal: 7
            )
        )

        #expect(input.translation == SIMD2<Float>(0, -1))
        #expect(input.isInteractionActive == false)
        #expect(input.cameraOrbitDelta == SIMD2<Float>(5, 6))
        #expect(input.cameraZoomDelta == 7)
        #expect(input.selectionPress == nil)
    }

    @Test func repeatedAndStaleRevisionsDoNotReplayOrReplaceState() {
        var input = InputState()
        let publication = snapshot(
            session: 1,
            sequence: 3,
            translation: SIMD2<Float>(0, 1),
            cameraOrbitTotal: SIMD2<Float>(4, -2),
            cameraZoomTotal: 5
        )
        input.ingest(publication)
        input.clearTransientInput()

        input.ingest(publication)
        input.ingest(
            snapshot(
                session: 1,
                sequence: 2,
                translation: SIMD2<Float>(1, 0),
                cameraOrbitTotal: SIMD2<Float>(100, 100),
                cameraZoomTotal: 100
            )
        )

        #expect(input.translation == SIMD2<Float>(0, 1))
        #expect(input.cameraOrbitDelta == .zero)
        #expect(input.cameraZoomDelta == 0)
    }

    @Test func skippedRevisionsPreserveCumulativeDifferencesAndLatestSelection() throws {
        var input = InputState()
        let firstSelection = try #require(
            SelectionPress(normalizedPosition: SIMD2<Float>(0.1, 0.2), aspectRatio: 1)
        )
        input.ingest(
            snapshot(
                session: 1,
                sequence: 1,
                cameraOrbitTotal: SIMD2<Float>(2, 1),
                cameraZoomTotal: 3,
                latestSelectionPress: firstSelection,
                selectionPressCount: 1
            )
        )
        input.clearTransientInput()

        let latestSelection = try #require(
            SelectionPress(normalizedPosition: SIMD2<Float>(0.8, 0.9), aspectRatio: 2)
        )
        input.ingest(
            snapshot(
                session: 1,
                sequence: 5,
                cameraOrbitTotal: SIMD2<Float>(9, -3),
                cameraZoomTotal: 11,
                latestSelectionPress: latestSelection,
                selectionPressCount: 3
            )
        )

        #expect(input.cameraOrbitDelta == SIMD2<Float>(7, -4))
        #expect(input.cameraZoomDelta == 8)
        #expect(input.selectionPress == latestSelection)

        input.clearTransientInput()
        input.ingest(
            snapshot(
                session: 1,
                sequence: 6,
                cameraOrbitTotal: SIMD2<Float>(9, -3),
                cameraZoomTotal: 11,
                latestSelectionPress: latestSelection,
                selectionPressCount: 3
            )
        )
        #expect(input.selectionPress == nil)
    }

    @Test func rebaseImportsHeldIntentAndConsumesHistoricalTransients() throws {
        var input = InputState()
        let baselineSelection = try #require(
            SelectionPress(normalizedPosition: SIMD2<Float>(0.4, 0.6), aspectRatio: 2)
        )
        let baseline = snapshot(
            session: 3,
            sequence: 8,
            translation: SIMD2<Float>(1, 0),
            isInteractionActive: true,
            cameraOrbitTotal: SIMD2<Float>(50, -40),
            cameraZoomTotal: 12,
            latestSelectionPress: baselineSelection,
            selectionPressCount: 4
        )
        input.rebase(to: baseline)

        #expect(input.translation == SIMD2<Float>(1, 0))
        #expect(input.isInteractionActive)
        #expect(input.cameraOrbitDelta == .zero)
        #expect(input.cameraZoomDelta == 0)
        #expect(input.selectionPress == nil)

        input.ingest(
            snapshot(
                session: 3,
                sequence: 9,
                translation: SIMD2<Float>(0, 1),
                cameraOrbitTotal: SIMD2<Float>(52, -43),
                cameraZoomTotal: 14,
                latestSelectionPress: baselineSelection,
                selectionPressCount: 4
            )
        )

        #expect(input.translation == SIMD2<Float>(0, 1))
        #expect(input.isInteractionActive == false)
        #expect(input.cameraOrbitDelta == SIMD2<Float>(2, -3))
        #expect(input.cameraZoomDelta == 2)
        #expect(input.selectionPress == nil)
    }

    @Test func cleanupClearsOnlyIntervalLocalSemanticInput() throws {
        var input = InputState()
        let selection = try #require(
            SelectionPress(normalizedPosition: SIMD2<Float>(0.5, 0.5), aspectRatio: 1)
        )
        input.ingest(
            snapshot(
                session: 1,
                sequence: 1,
                translation: SIMD2<Float>(-1, 0),
                isInteractionActive: true,
                cameraOrbitTotal: SIMD2<Float>(1, 2),
                cameraZoomTotal: -2,
                latestSelectionPress: selection,
                selectionPressCount: 1
            )
        )

        input.clearTransientInput()

        #expect(input.translation == SIMD2<Float>(-1, 0))
        #expect(input.isInteractionActive)
        #expect(input.cameraOrbitDelta == .zero)
        #expect(input.cameraZoomDelta == 0)
        #expect(input.selectionPress == nil)
    }

    @Test func invalidSemanticSnapshotIsIgnoredAtomically() {
        var input = InputState()
        input.ingest(
            snapshot(
                session: 1,
                sequence: 1,
                translation: SIMD2<Float>(0, 1)
            )
        )
        input.clearTransientInput()

        input.ingest(
            snapshot(
                session: 1,
                sequence: 2,
                translation: SIMD2<Float>(2, 0),
                cameraOrbitTotal: SIMD2<Float>(4, 5)
            )
        )

        #expect(input.translation == SIMD2<Float>(0, 1))
        #expect(input.cameraOrbitDelta == .zero)
    }

    @Test func quickFireTapSurvivesSkippedPublicationsAndDoesNotRepeatOnCatchup() {
        let runtime = InputRuntime()
        runtime.start()
        var input = InputState()
        input.ingest(runtime.latestInputSnapshot)

        runtime.receive(.keyDown(KeyboardKey(keyCode: 46)))
        runtime.receive(.keyUp(KeyboardKey(keyCode: 46)))
        let releasedPublication = runtime.latestInputSnapshot
        input.ingest(releasedPublication)
        #expect(input.isFireRequested)

        input.clearTransientInput()
        input.ingest(releasedPublication)
        #expect(input.isFireRequested == false)

        runtime.receive(.keyDown(KeyboardKey(keyCode: 46)))
        input.ingest(runtime.latestInputSnapshot)
        #expect(input.isFireRequested)

        input.clearTransientInput()
        runtime.receive(.keyDown(KeyboardKey(keyCode: 46)))
        input.ingest(runtime.latestInputSnapshot)
        #expect(input.isFireRequested == false)
    }

    @Test func multipleFirePressesCoalesceAndRemainPendingUntilCleanup() {
        var input = InputState()
        input.ingest(snapshot(session: 1, sequence: 1, firePressCount: 1))
        input.clearTransientInput()

        input.ingest(snapshot(session: 1, sequence: 7, firePressCount: 4))
        #expect(input.isFireRequested)
        input.ingest(snapshot(session: 1, sequence: 8, firePressCount: 4))
        #expect(input.isFireRequested)

        input.clearTransientInput()
        input.ingest(snapshot(session: 1, sequence: 9, firePressCount: 4))
        #expect(input.isFireRequested == false)
    }

    @Test func rebaseConsumesHistoricalFireAndClearsAPendingRequest() {
        var input = InputState()
        input.ingest(snapshot(session: 1, sequence: 1, firePressCount: 1))
        #expect(input.isFireRequested)

        let baseline = snapshot(session: 1, sequence: 5, firePressCount: 3)
        input.rebase(to: baseline)
        #expect(input.isFireRequested == false)
        input.ingest(baseline)
        #expect(input.isFireRequested == false)

        input.ingest(snapshot(session: 1, sequence: 6, firePressCount: 4))
        #expect(input.isFireRequested)
    }

    @Test func newSessionFireCountsStartAtZeroAndOldSessionCannotReplay() {
        var input = InputState()
        let oldPublication = snapshot(session: 1, sequence: 9, firePressCount: 4)
        input.ingest(oldPublication)
        #expect(input.isFireRequested)
        input.clearTransientInput()

        input.ingest(snapshot(session: 2, sequence: 0, firePressCount: 0))
        #expect(input.isFireRequested == false)
        input.ingest(snapshot(session: 2, sequence: 1, firePressCount: 1))
        #expect(input.isFireRequested)
        input.clearTransientInput()

        input.ingest(oldPublication)
        #expect(input.isFireRequested == false)
        input.ingest(snapshot(session: 3, sequence: 2, firePressCount: 1))
        #expect(input.isFireRequested)
    }

    @Test func decreasingFireCountRejectsTheEntirePublication() {
        var input = InputState()
        input.ingest(snapshot(session: 1, sequence: 4, translation: SIMD2<Float>(0, 1), firePressCount: 2))
        input.clearTransientInput()

        input.ingest(snapshot(session: 1, sequence: 6, translation: SIMD2<Float>(1, 0), firePressCount: 1))
        #expect(input.translation == SIMD2<Float>(0, 1))
        #expect(input.isFireRequested == false)

        input.ingest(snapshot(session: 1, sequence: 5, firePressCount: 3))
        #expect(input.isFireRequested)
    }

    private func snapshot(
        session: UInt64,
        sequence: UInt64,
        translation: SIMD2<Float> = .zero,
        isInteractionActive: Bool = false,
        cameraOrbitTotal: SIMD2<Float> = .zero,
        cameraZoomTotal: Float = 0,
        latestSelectionPress: SelectionPress? = nil,
        selectionPressCount: UInt64 = 0,
        firePressCount: UInt64 = 0
    ) -> InputSnapshot {
        InputSnapshot(
            revision: InputRevision(session: session, sequence: sequence),
            translation: translation,
            isInteractionActive: isInteractionActive,
            cameraOrbitTotal: cameraOrbitTotal,
            cameraZoomTotal: cameraZoomTotal,
            latestSelectionPress: latestSelectionPress,
            selectionPressCount: selectionPressCount,
            firePressCount: firePressCount
        )
    }
}
