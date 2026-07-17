import simd
import Testing
@testable import Engine2

struct InputHistoryTests {
    @Test func emptyFrameDoesNotAddHistoryRow() async throws {
        var input = InputState()

        input.recordHistoryFrame()

        #expect(input.history.isEmpty)
    }

    @Test func changedInputAddsNewestRowFirst() async throws {
        var input = InputState()
        let key = KeyboardKey.make(keyCode: 13, charactersIgnoringModifiers: "w")

        input.ingest(
            snapshot(session: 1, sequence: 1, pressedKeys: [key])
        )
        input.recordHistoryFrame()
        input.ingest(
            snapshot(
                session: 1,
                sequence: 2,
                pressedMouseButtons: [.left],
                pressedKeys: [key]
            )
        )
        input.recordHistoryFrame()

        #expect(input.history.count == 2)
        #expect(input.history[0].tokens == ["LMB", "W"])
        #expect(input.history[1].tokens == ["W"])
    }

    @Test func identicalHeldInputIncrementsDuration() async throws {
        var input = InputState()
        input.ingest(
            snapshot(
                session: 1,
                sequence: 1,
                pressedMouseButtons: [.left]
            )
        )

        input.recordHistoryFrame()
        input.recordHistoryFrame()

        #expect(input.history.count == 1)
        #expect(input.history[0].tokens == ["LMB"])
        #expect(input.history[0].frameCount == 2)
    }

    @Test func historyRespectsLimit() async throws {
        var input = InputState()
        input.historyLimit = 3
        var pointerMotionTotal = SIMD2<Float>.zero

        for index in 0..<5 {
            pointerMotionTotal += SIMD2<Float>(Float(index + 1), 0)
            input.ingest(
                snapshot(
                    session: 1,
                    sequence: UInt64(index + 1),
                    pointerMotionTotal: pointerMotionTotal
                )
            )
            input.recordHistoryFrame()
            input.clearTransientInput()
        }

        #expect(input.history.count == 3)
        #expect(input.history[0].tokens == ["Mouse dx:+5 dy:+0"])
        #expect(input.history[2].tokens == ["Mouse dx:+3 dy:+0"])
    }

    @Test func zeroHistoryLimitRetainsNoRows() {
        var input = InputState()
        input.historyLimit = 0
        input.ingest(
            snapshot(
                session: 1,
                sequence: 1,
                pressedMouseButtons: [.left]
            )
        )

        input.recordHistoryFrame()

        #expect(input.history.isEmpty)
    }

    private func snapshot(
        session: UInt64,
        sequence: UInt64,
        pointerMotionTotal: SIMD2<Float> = .zero,
        pressedMouseButtons: Set<MouseButton> = [],
        pressedKeys: Set<KeyboardKey> = []
    ) -> InputSnapshot {
        InputSnapshot(
            revision: InputRevision(session: session, sequence: sequence),
            pointerPosition: .zero,
            pointerMotionTotal: pointerMotionTotal,
            scrollTotal: .zero,
            pressedMouseButtons: pressedMouseButtons,
            pressedKeys: pressedKeys
        )
    }
}
