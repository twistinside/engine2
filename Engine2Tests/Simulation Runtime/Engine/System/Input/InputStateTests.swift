//
//  InputStateTests.swift
//  Engine2Tests
//
//  Created by Codex on 6/14/26.
//

import simd
import Testing
@testable import Engine2

struct InputStateTests {
    @Test func initialAndNewSessionCumulativeTotalsApplyFromZero() {
        var input = InputState()

        input.ingest(
            snapshot(
                session: 1,
                sequence: 4,
                position: SIMD2<Float>(13, 18),
                pointerMotionTotal: SIMD2<Float>(3, -2),
                scrollTotal: SIMD2<Float>(0, -4),
                pressedMouseButtons: [.left]
            )
        )

        #expect(input.mouse.buttons == [.left])
        #expect(input.mouse.position == SIMD2<Float>(13, 18))
        #expect(input.mouse.delta == SIMD2<Float>(3, -2))
        #expect(input.mouse.scrollDelta == SIMD2<Float>(0, -4))

        input.clearTransientInput()
        input.ingest(
            snapshot(
                session: 2,
                sequence: 2,
                position: SIMD2<Float>(20, 30),
                pointerMotionTotal: SIMD2<Float>(5, 6),
                scrollTotal: SIMD2<Float>(0, 7)
            )
        )

        #expect(input.mouse.position == SIMD2<Float>(20, 30))
        #expect(input.mouse.delta == SIMD2<Float>(5, 6))
        #expect(input.mouse.scrollDelta == SIMD2<Float>(0, 7))
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

        input.ingest(
            snapshot(
                session: 1,
                sequence: 1,
                pointerMotionTotal: SIMD2<Float>(2, 1),
                scrollTotal: SIMD2<Float>(0, 3)
            )
        )
        input.clearTransientInput()

        input.ingest(
            snapshot(
                session: 1,
                sequence: 5,
                pointerMotionTotal: SIMD2<Float>(9, -3),
                scrollTotal: SIMD2<Float>(0, 11)
            )
        )

        #expect(input.mouse.delta == SIMD2<Float>(7, -4))
        #expect(input.mouse.scrollDelta == SIMD2<Float>(0, 8))
    }

    @Test func staleRevisionIsIgnored() {
        var input = InputState()
        let heldKey = KeyboardKey.make(
            keyCode: 13,
            charactersIgnoringModifiers: "w"
        )

        input.ingest(
            snapshot(
                session: 2,
                sequence: 5,
                position: SIMD2<Float>(8, 9),
                pointerMotionTotal: SIMD2<Float>(4, 3),
                pressedMouseButtons: [.right],
                pressedKeys: [heldKey]
            )
        )
        input.clearTransientInput()

        input.ingest(
            snapshot(
                session: 2,
                sequence: 4,
                position: SIMD2<Float>(100, 100),
                pointerMotionTotal: SIMD2<Float>(100, 100)
            )
        )

        #expect(input.mouse.position == SIMD2<Float>(8, 9))
        #expect(input.mouse.buttons == [.right])
        #expect(input.keyboard.keys == [heldKey])
        #expect(input.mouse.delta == .zero)
        #expect(input.mouse.scrollDelta == .zero)
    }

    @Test func rebaseImportsPersistentStateWithoutHistoricalTransients() {
        var input = InputState()
        let heldKey = KeyboardKey.make(
            keyCode: 49,
            charactersIgnoringModifiers: " "
        )

        input.rebase(
            to: snapshot(
                session: 3,
                sequence: 8,
                position: SIMD2<Float>(21, 34),
                pointerMotionTotal: SIMD2<Float>(50, -40),
                scrollTotal: SIMD2<Float>(0, 12),
                pressedMouseButtons: [.left],
                pressedKeys: [heldKey]
            )
        )

        #expect(input.mouse.position == SIMD2<Float>(21, 34))
        #expect(input.mouse.buttons == [.left])
        #expect(input.keyboard.keys == [heldKey])
        #expect(input.mouse.delta == .zero)
        #expect(input.mouse.scrollDelta == .zero)

        input.ingest(
            snapshot(
                session: 3,
                sequence: 9,
                position: SIMD2<Float>(23, 31),
                pointerMotionTotal: SIMD2<Float>(52, -43),
                scrollTotal: SIMD2<Float>(0, 14),
                pressedMouseButtons: [.left],
                pressedKeys: [heldKey]
            )
        )

        #expect(input.mouse.delta == SIMD2<Float>(2, -3))
        #expect(input.mouse.scrollDelta == SIMD2<Float>(0, 2))
    }

    @Test func newerSnapshotUpdatesHeldKeyboardState() {
        var input = InputState()
        let key = KeyboardKey.make(keyCode: 13, charactersIgnoringModifiers: "w")

        input.ingest(
            snapshot(session: 1, sequence: 1, pressedKeys: [key])
        )
        #expect(input.keyboard.keys == [key])

        input.ingest(snapshot(session: 1, sequence: 2))
        #expect(input.keyboard.keys.isEmpty)
    }

    @Test func newerSnapshotUpdatesHeldButtonsAndPointerPosition() {
        var input = InputState()

        input.ingest(
            snapshot(
                session: 1,
                sequence: 1,
                position: SIMD2<Float>(2, 3),
                pressedMouseButtons: [.right]
            )
        )
        input.ingest(
            snapshot(
                session: 1,
                sequence: 2,
                position: SIMD2<Float>(8, 9)
            )
        )

        #expect(input.mouse.buttons.isEmpty)
        #expect(input.mouse.position == SIMD2<Float>(8, 9))
    }

    @Test func historyTokensHaveStableOrderingAndRoundedDeltas() {
        var input = InputState()
        let aKey = KeyboardKey.make(
            keyCode: 0,
            charactersIgnoringModifiers: "a"
        )
        let zKey = KeyboardKey.make(
            keyCode: 6,
            charactersIgnoringModifiers: "z"
        )

        input.ingest(
            snapshot(
                session: 1,
                sequence: 1,
                pointerMotionTotal: SIMD2<Float>(1.6, -1.6),
                scrollTotal: SIMD2<Float>(0, 0.4),
                pressedMouseButtons: [.other(5), .middle, .right, .left],
                pressedKeys: [zKey, aKey]
            )
        )

        #expect(
            input.currentHistoryTokens() == [
                "LMB",
                "RMB",
                "MMB",
                "M5",
                "Mouse dx:+2 dy:-2",
                "Wheel:+0",
                "A",
                "Z"
            ]
        )
    }

    @Test func cleanupClearsDeltasAndActionsButPreservesHeldState() {
        var input = InputState()
        let key = KeyboardKey.make(keyCode: 49, charactersIgnoringModifiers: " ")

        input.ingest(
            snapshot(
                session: 1,
                sequence: 1,
                position: SIMD2<Float>(5, 0),
                pointerMotionTotal: SIMD2<Float>(5, 0),
                scrollTotal: SIMD2<Float>(0, 2),
                pressedMouseButtons: [.left],
                pressedKeys: [key]
            )
        )
        input.actions.cameraOrbitDelta = SIMD2<Float>(1, 0)
        input.actions.cameraZoomDelta = 1

        input.clearTransientInput()

        #expect(input.mouse.buttons == [.left])
        #expect(input.keyboard.keys == [key])
        #expect(input.mouse.delta == .zero)
        #expect(input.mouse.scrollDelta == .zero)
        #expect(input.actions.cameraOrbitDelta == .zero)
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
        InputSnapshot(
            revision: InputRevision(session: session, sequence: sequence),
            pointerPosition: position,
            pointerMotionTotal: pointerMotionTotal,
            scrollTotal: scrollTotal,
            pressedMouseButtons: pressedMouseButtons,
            pressedKeys: pressedKeys
        )
    }
}
