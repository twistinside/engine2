import Testing
@testable import Engine2

struct InputHistoryEntryTests {
    @Test func tokenTextJoinsTokensForCompactDisplay() {
        let entry = InputHistoryEntry(
            id: 1,
            frameIndex: 12,
            frameCount: 3,
            tokens: ["Move x:+1.00 y:+0.00", "Interact", "Zoom:-2.00"]
        )

        #expect(entry.tokenText == "Move x:+1.00 y:+0.00  Interact  Zoom:-2.00")
    }
}
