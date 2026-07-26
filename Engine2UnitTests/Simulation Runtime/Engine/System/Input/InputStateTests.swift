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
        let publication = snapshot(
            session: 1,
            sequence: 3,
            pointerMotionTotal: SIMD2<Float>(4, -2),
            scrollTotal: SIMD2<Float>(0, 5)
        )

        input.ingest(publication)
        input.clearTransientInput()
        input.ingest(publication)

        #expect(input.mouse.delta == .zero)
        #expect(input.mouse.scrollDelta == .zero)
    }

    @Test func skippedRevisionsPreserveCumulativeDifferences() {
        var input = InputState()

        let initialSnapshot = snapshot(
            session: 1,
            sequence: 1,
            pointerMotionTotal: SIMD2<Float>(2, 1),
            scrollTotal: SIMD2<Float>(0, 3)
        )
        input.ingest(initialSnapshot)
        input.clearTransientInput()

        let nextSnapshot = snapshot(
            session: 1,
            sequence: 5,
            pointerMotionTotal: SIMD2<Float>(9, -3),
            scrollTotal: SIMD2<Float>(0, 11)
        )
        input.ingest(nextSnapshot)

        #expect(input.mouse.delta == SIMD2<Float>(7, -4))
        #expect(input.mouse.scrollDelta == SIMD2<Float>(0, 8))
    }

    @Test func staleRevisionIsIgnored() {
        var input = InputState()
        let heldKey = KeyboardKey(
            keyCode: 13,
            charactersIgnoringModifiers: "w"
        )

        let currentPosition = SIMD2<Float>(8, 9)
        let currentSnapshot = snapshot(
            session: 2,
            sequence: 5,
            position: currentPosition,
            pointerMotionTotal: SIMD2<Float>(4, 3),
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
        let newerSnapshot = snapshot(
            session: 2,
            sequence: 6,
            position: newerPosition,
            pointerMotionTotal: SIMD2<Float>(7, 5)
        )
        input.ingest(newerSnapshot)

        #expect(input.mouse.position == newerPosition)
        #expect(input.mouse.delta == SIMD2<Float>(3, 2))
    }

    @Test func rebaseImportsPersistentStateWithoutHistoricalTransients() {
        var input = InputState()
        let heldKey = KeyboardKey(
            keyCode: 49,
            charactersIgnoringModifiers: " "
        )

        let baselinePosition = SIMD2<Float>(21, 34)
        let baseline = snapshot(
            session: 3,
            sequence: 8,
            position: baselinePosition,
            pointerMotionTotal: SIMD2<Float>(50, -40),
            scrollTotal: SIMD2<Float>(0, 12),
            pressedMouseButtons: [.left],
            pressedKeys: [heldKey]
        )
        input.rebase(to: baseline)

        #expect(input.mouse.position == baselinePosition)
        #expect(input.mouse.buttons == [.left])
        #expect(input.keyboard.keys == [heldKey])
        #expect(input.mouse.delta == .zero)
        #expect(input.mouse.scrollDelta == .zero)

        let nextSnapshot = snapshot(
            session: 3,
            sequence: 9,
            position: SIMD2<Float>(23, 31),
            pointerMotionTotal: SIMD2<Float>(52, -43),
            scrollTotal: SIMD2<Float>(0, 14),
            pressedMouseButtons: [.left],
            pressedKeys: [heldKey]
        )
        input.ingest(nextSnapshot)

        #expect(input.mouse.delta == SIMD2<Float>(2, -3))
        #expect(input.mouse.scrollDelta == SIMD2<Float>(0, 2))
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

        let initialSnapshot = snapshot(
            session: 1,
            sequence: 1,
            position: SIMD2<Float>(2, 3),
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
        let snapshot = snapshot(
            session: 1,
            sequence: 1,
            position: position,
            pointerMotionTotal: position,
            scrollTotal: SIMD2<Float>(0, 2),
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
