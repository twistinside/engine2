import Testing
@testable import Engine2

struct InputHistoryTests {
    @Test func emptyFrameAdvancesFrameIndexWithoutAddingHistoryRow() {
        var input = InputState()
        var history = InputHistory(maximumEntryCount: 60)

        history.record(input: input)
        input.translation = SIMD2<Float>(1, 0)
        history.record(input: input)

        #expect(history.entries.count == 1)
        #expect(history.entries[0].frameIndex == 2)
        #expect(history.entries[0].tokens == ["Move x:+1.00 y:+0.00"])
    }

    @Test func identicalHeldIntentCoalescesAcrossConsecutiveFrames() {
        var input = InputState()
        var history = InputHistory(maximumEntryCount: 60)
        input.isInteractionActive = true

        history.record(input: input)
        history.record(input: input)

        #expect(history.entries.count == 1)
        #expect(history.entries[0].tokens == ["Interact"])
        #expect(history.entries[0].frameCount == 2)
    }

    @Test func matchingInputSeparatedByAnEmptyFrameStartsANewEntry() {
        var input = InputState()
        var history = InputHistory(maximumEntryCount: 60)

        input.isInteractionActive = true
        history.record(input: input)
        input.isInteractionActive = false
        history.record(input: input)
        input.isInteractionActive = true
        history.record(input: input)

        #expect(history.entries.count == 2)
        #expect(history.entries.map(\.frameIndex) == [3, 1])
        #expect(history.entries.map(\.frameCount) == [1, 1])
    }

    @Test func historyRespectsImmutableLimit() {
        var input = InputState()
        var history = InputHistory(maximumEntryCount: 3)

        for index in 1...5 {
            input.cameraZoomDelta = Float(index)
            history.record(input: input)
        }

        #expect(history.maximumEntryCount == 3)
        #expect(history.entries.count == 3)
        #expect(history.entries[0].tokens == ["Zoom:+5.00"])
        #expect(history.entries[2].tokens == ["Zoom:+3.00"])
    }

    @Test func zeroHistoryLimitRetainsNoRows() {
        var input = InputState()
        var history = InputHistory(maximumEntryCount: 0)
        input.isInteractionActive = true

        history.record(input: input)

        #expect(history.entries.isEmpty)
    }

    @Test func tokensDescribeSemanticIntentInStableOrder() throws {
        var input = InputState()
        var history = InputHistory(maximumEntryCount: 1)
        input.translation = SIMD2<Float>(-1, 0)
        input.isInteractionActive = true
        input.cameraOrbitDelta = SIMD2<Float>(1.6, -1.6)
        input.cameraZoomDelta = 0.4
        input.selectionPress = try #require(
            SelectionPress(normalizedPosition: SIMD2<Float>(0.25, 0.75), aspectRatio: 2)
        )

        history.record(input: input)

        #expect(
            history.entries.first?.tokens == [
                "Move x:-1.00 y:+0.00",
                "Interact",
                "Orbit dx:+1.60 dy:-1.60",
                "Zoom:+0.40",
                "Select x:+0.25 y:+0.75"
            ]
        )
    }
}
