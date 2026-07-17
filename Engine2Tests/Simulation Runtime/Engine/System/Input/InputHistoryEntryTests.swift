import Testing
@testable import Engine2

struct InputHistoryEntryTests {
    @Test func tokenTextJoinsTokensForCompactDisplay() {
        let entry = InputHistoryEntry(
            id: 1,
            frameIndex: 12,
            frameCount: 3,
            tokens: ["LMB", "Mouse dx:+2 dy:-1", "W"]
        )

        #expect(entry.tokenText == "LMB  Mouse dx:+2 dy:-1  W")
    }
}
