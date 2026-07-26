import simd
import Testing
@testable import Engine2

struct InputHistoryTests {
    @Test func emptyFrameAdvancesFrameIndexWithoutAddingHistoryRow() {
        var input = InputState()
        var history = InputHistory(maximumEntryCount: 60)

        history.record(input: input)
        input.mouse.buttons = [.left]
        history.record(input: input)

        #expect(history.entries.count == 1)
        #expect(history.entries[0].frameIndex == 2)
        #expect(history.entries[0].tokens == ["LMB"])
    }

    @Test func changedInputAddsNewestRowFirst() {
        var input = InputState()
        var history = InputHistory(maximumEntryCount: 60)
        let key = KeyboardKey(keyCode: 13, charactersIgnoringModifiers: "w")

        input.ingest(
            snapshot(session: 1, sequence: 1, pressedKeys: [key])
        )
        history.record(input: input)
        input.ingest(
            snapshot(
                session: 1,
                sequence: 2,
                pressedMouseButtons: [.left],
                pressedKeys: [key]
            )
        )
        history.record(input: input)

        #expect(history.entries.count == 2)
        #expect(history.entries[0].tokens == ["LMB", "W"])
        #expect(history.entries[1].tokens == ["W"])
    }

    @Test func identicalHeldInputIncrementsDuration() {
        var input = InputState()
        var history = InputHistory(maximumEntryCount: 60)
        input.ingest(
            snapshot(
                session: 1,
                sequence: 1,
                pressedMouseButtons: [.left]
            )
        )

        history.record(input: input)
        history.record(input: input)

        #expect(history.entries.count == 1)
        #expect(history.entries[0].tokens == ["LMB"])
        #expect(history.entries[0].frameCount == 2)
    }

    @Test func matchingInputSeparatedByAnEmptyFrameStartsANewEntry() {
        var input = InputState()
        var history = InputHistory(maximumEntryCount: 60)

        input.mouse.buttons = [.left]
        history.record(input: input)
        input.mouse.buttons = []
        history.record(input: input)
        input.mouse.buttons = [.left]
        history.record(input: input)

        #expect(history.entries.count == 2)
        #expect(history.entries.map(\.frameIndex) == [3, 1])
        #expect(history.entries.map(\.frameCount) == [1, 1])
    }

    @Test func historyRespectsImmutableLimit() {
        var input = InputState()
        var history = InputHistory(maximumEntryCount: 3)
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
            history.record(input: input)
            input.clearTransientInput()
        }

        #expect(history.maximumEntryCount == 3)
        #expect(history.entries.count == 3)
        #expect(history.entries[0].tokens == ["Mouse dx:+5 dy:+0"])
        #expect(history.entries[2].tokens == ["Mouse dx:+3 dy:+0"])
    }

    @Test func zeroHistoryLimitRetainsNoRows() {
        var input = InputState()
        var history = InputHistory(maximumEntryCount: 0)
        input.mouse.buttons = [.left]

        history.record(input: input)

        #expect(history.entries.isEmpty)
    }

    @Test func tokensHaveStableOrderingAndRoundedDeltas() {
        var input = InputState()
        var history = InputHistory(maximumEntryCount: 1)
        let aKey = KeyboardKey(keyCode: 0, charactersIgnoringModifiers: "a")
        let zKey = KeyboardKey(keyCode: 6, charactersIgnoringModifiers: "z")

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
        history.record(input: input)

        #expect(
            history.entries.first?.tokens == [
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

    @Test func formattingHandlesNonfiniteAndVeryLargeDeltas() {
        var input = InputState()
        var history = InputHistory(maximumEntryCount: 1)
        input.mouse.delta = SIMD2<Float>(.nan, .infinity)
        input.mouse.scrollDelta = SIMD2<Float>(
            0,
            -.greatestFiniteMagnitude
        )

        history.record(input: input)

        #expect(
            history.entries.first?.tokens == [
                "Mouse dx:+nan dy:+inf",
                "Wheel:-\(Float.greatestFiniteMagnitude)"
            ]
        )
    }

    private func snapshot(
        session: UInt64,
        sequence: UInt64,
        pointerMotionTotal: SIMD2<Float> = .zero,
        scrollTotal: SIMD2<Float> = .zero,
        pressedMouseButtons: Set<MouseButton> = [],
        pressedKeys: Set<KeyboardKey> = []
    ) -> InputSnapshot {
        InputSnapshot(
            revision: InputRevision(session: session, sequence: sequence),
            pointerPosition: .zero,
            pointerMotionTotal: pointerMotionTotal,
            scrollTotal: scrollTotal,
            pressedMouseButtons: pressedMouseButtons,
            pressedKeys: pressedKeys
        )
    }
}
