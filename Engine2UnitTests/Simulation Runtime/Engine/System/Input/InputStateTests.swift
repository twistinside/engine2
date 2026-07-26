import simd
import Testing
@testable import Engine2

struct InputStateTests {
    @Test func initialAndNewSessionCumulativeTotalsApplyFromZero() {
        var input = InputState()

        let initialPosition = SIMD2<Float>(13, 18)
        let initialPointerMotionTotal = SIMD2<Float>(3, -2)
        let initialScrollTotal = SIMD2<Float>(0, -4)
        let initialSnapshot = snapshot(
            session: 1,
            sequence: 4,
            position: initialPosition,
            pointerMotionTotal: initialPointerMotionTotal,
            scrollTotal: initialScrollTotal,
            pressedMouseButtons: [.left]
        )
        input.ingest(initialSnapshot)

        #expect(input.mouse.buttons == [.left])
        #expect(input.mouse.position == initialPosition)
        #expect(input.mouse.delta == initialPointerMotionTotal)
        #expect(input.mouse.scrollDelta == initialScrollTotal)

        input.clearTransientInput()
        let nextPosition = SIMD2<Float>(20, 30)
        let nextPointerMotionTotal = SIMD2<Float>(5, 6)
        let nextScrollTotal = SIMD2<Float>(0, 7)
        let nextSnapshot = snapshot(
            session: 2,
            sequence: 2,
            position: nextPosition,
            pointerMotionTotal: nextPointerMotionTotal,
            scrollTotal: nextScrollTotal
        )
        input.ingest(nextSnapshot)

        #expect(input.mouse.position == nextPosition)
        #expect(input.mouse.delta == nextPointerMotionTotal)
        #expect(input.mouse.scrollDelta == nextScrollTotal)
    }

    @Test func sameRevisionDoesNotReplayTransientInput() {
        var input = InputState()
        let pointerMotionTotal = SIMD2<Float>(4, -2)
        let scrollTotal = SIMD2<Float>(0, 5)
        let publication = snapshot(
            session: 1,
            sequence: 3,
            pointerMotionTotal: pointerMotionTotal,
            scrollTotal: scrollTotal
        )

        input.ingest(publication)
        input.clearTransientInput()
        input.ingest(publication)

        #expect(input.mouse.delta == .zero)
        #expect(input.mouse.scrollDelta == .zero)
    }

    @Test func skippedRevisionsPreserveCumulativeDifferences() {
        var input = InputState()

        let initialPointerMotionTotal = SIMD2<Float>(2, 1)
        let initialScrollTotal = SIMD2<Float>(0, 3)
        let initialSnapshot = snapshot(
            session: 1,
            sequence: 1,
            pointerMotionTotal: initialPointerMotionTotal,
            scrollTotal: initialScrollTotal
        )
        input.ingest(initialSnapshot)
        input.clearTransientInput()

        let nextPointerMotionTotal = SIMD2<Float>(9, -3)
        let nextScrollTotal = SIMD2<Float>(0, 11)
        let nextSnapshot = snapshot(
            session: 1,
            sequence: 5,
            pointerMotionTotal: nextPointerMotionTotal,
            scrollTotal: nextScrollTotal
        )
        input.ingest(nextSnapshot)

        let expectedPointerDelta = SIMD2<Float>(7, -4)
        let expectedScrollDelta = SIMD2<Float>(0, 8)

        #expect(input.mouse.delta == expectedPointerDelta)
        #expect(input.mouse.scrollDelta == expectedScrollDelta)
    }

    @Test func staleRevisionIsIgnored() {
        var input = InputState()
        let heldKey = KeyboardKey(
            keyCode: 13,
            charactersIgnoringModifiers: "w"
        )

        let currentPosition = SIMD2<Float>(8, 9)
        let currentPointerMotionTotal = SIMD2<Float>(4, 3)
        let currentSnapshot = snapshot(
            session: 2,
            sequence: 5,
            position: currentPosition,
            pointerMotionTotal: currentPointerMotionTotal,
            pressedMouseButtons: [.right],
            pressedKeys: [heldKey]
        )
        input.ingest(currentSnapshot)
        input.clearTransientInput()

        let stalePosition = SIMD2<Float>(100, 100)
        let staleSnapshot = snapshot(
            session: 2,
            sequence: 4,
            position: stalePosition,
            pointerMotionTotal: stalePosition
        )
        input.ingest(staleSnapshot)

        #expect(input.mouse.position == currentPosition)
        #expect(input.mouse.buttons == [.right])
        #expect(input.keyboard.keys == [heldKey])
        #expect(input.mouse.delta == .zero)
        #expect(input.mouse.scrollDelta == .zero)

        let newerPosition = SIMD2<Float>(9, 10)
        let newerPointerMotionTotal = SIMD2<Float>(7, 5)
        let newerSnapshot = snapshot(
            session: 2,
            sequence: 6,
            position: newerPosition,
            pointerMotionTotal: newerPointerMotionTotal
        )
        input.ingest(newerSnapshot)

        let expectedPointerDelta = SIMD2<Float>(3, 2)

        #expect(input.mouse.position == newerPosition)
        #expect(input.mouse.delta == expectedPointerDelta)
    }

    @Test func rebaseImportsPersistentStateWithoutHistoricalTransients() {
        var input = InputState()
        let heldKey = KeyboardKey(
            keyCode: 49,
            charactersIgnoringModifiers: " "
        )

        let baselinePosition = SIMD2<Float>(21, 34)
        let baselinePointerMotionTotal = SIMD2<Float>(50, -40)
        let baselineScrollTotal = SIMD2<Float>(0, 12)
        let baseline = snapshot(
            session: 3,
            sequence: 8,
            position: baselinePosition,
            pointerMotionTotal: baselinePointerMotionTotal,
            scrollTotal: baselineScrollTotal,
            pressedMouseButtons: [.left],
            pressedKeys: [heldKey]
        )
        input.rebase(to: baseline)

        #expect(input.mouse.position == baselinePosition)
        #expect(input.mouse.buttons == [.left])
        #expect(input.keyboard.keys == [heldKey])
        #expect(input.mouse.delta == .zero)
        #expect(input.mouse.scrollDelta == .zero)

        let nextPosition = SIMD2<Float>(23, 31)
        let nextPointerMotionTotal = SIMD2<Float>(52, -43)
        let nextScrollTotal = SIMD2<Float>(0, 14)
        let nextSnapshot = snapshot(
            session: 3,
            sequence: 9,
            position: nextPosition,
            pointerMotionTotal: nextPointerMotionTotal,
            scrollTotal: nextScrollTotal,
            pressedMouseButtons: [.left],
            pressedKeys: [heldKey]
        )
        input.ingest(nextSnapshot)

        let expectedPointerDelta = SIMD2<Float>(2, -3)
        let expectedScrollDelta = SIMD2<Float>(0, 2)

        #expect(input.mouse.delta == expectedPointerDelta)
        #expect(input.mouse.scrollDelta == expectedScrollDelta)
    }

    @Test func newerSnapshotUpdatesHeldKeyboardState() {
        var input = InputState()
        let key = KeyboardKey(keyCode: 13, charactersIgnoringModifiers: "w")

        let heldKeySnapshot = snapshot(
            session: 1,
            sequence: 1,
            pressedKeys: [key]
        )
        input.ingest(heldKeySnapshot)
        #expect(input.keyboard.keys == [key])

        let releasedKeySnapshot = snapshot(session: 1, sequence: 2)
        input.ingest(releasedKeySnapshot)
        #expect(input.keyboard.keys.isEmpty)
    }

    @Test func newerSnapshotUpdatesHeldButtonsAndPointerPosition() {
        var input = InputState()

        let initialPosition = SIMD2<Float>(2, 3)
        let initialSnapshot = snapshot(
            session: 1,
            sequence: 1,
            position: initialPosition,
            pressedMouseButtons: [.right]
        )
        input.ingest(initialSnapshot)
        let updatedPosition = SIMD2<Float>(8, 9)
        let updatedSnapshot = snapshot(
            session: 1,
            sequence: 2,
            position: updatedPosition
        )
        input.ingest(updatedSnapshot)

        #expect(input.mouse.buttons.isEmpty)
        #expect(input.mouse.position == updatedPosition)
    }

    @Test func cleanupClearsDeltasButPreservesHeldState() {
        var input = InputState()
        let key = KeyboardKey(keyCode: 49, charactersIgnoringModifiers: " ")

        let position = SIMD2<Float>(5, 0)
        let scrollTotal = SIMD2<Float>(0, 2)
        let snapshot = snapshot(
            session: 1,
            sequence: 1,
            position: position,
            pointerMotionTotal: position,
            scrollTotal: scrollTotal,
            pressedMouseButtons: [.left],
            pressedKeys: [key]
        )
        input.ingest(snapshot)
        input.actions.cameraOrbitYawDelta = 1
        input.actions.cameraZoomDelta = -2
        input.clearTransientInput()

        #expect(input.mouse.buttons == [.left])
        #expect(input.keyboard.keys == [key])
        #expect(input.mouse.delta == .zero)
        #expect(input.mouse.scrollDelta == .zero)
        #expect(input.actions.cameraOrbitYawDelta == 0)
        #expect(input.actions.cameraZoomDelta == 0)
    }

    private func snapshot(
        session: UInt64,
        sequence: UInt64,
        position: SIMD2<Float> = .zero,
        pointerMotionTotal: SIMD2<Float> = .zero,
        scrollTotal: SIMD2<Float> = .zero,
        pressedMouseButtons: Set<MouseButton> = [],
        pressedKeys: Set<KeyboardKey> = []
    ) -> InputSnapshot {
        let revision = InputRevision(session: session, sequence: sequence)
        return InputSnapshot(
            revision: revision,
            pointerPosition: position,
            pointerMotionTotal: pointerMotionTotal,
            scrollTotal: scrollTotal,
            pressedMouseButtons: pressedMouseButtons,
            pressedKeys: pressedKeys
        )
    }
}
