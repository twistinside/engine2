import Testing
@testable import Engine2

struct KeyboardKeyTests {
    @Test func namedKeysUseStablePlatformNeutralDisplayNames() {
        let expectedNames: [UInt16: String] = [
            36: "Return",
            48: "Tab",
            49: "Space",
            51: "Delete",
            53: "Escape",
            123: "Left",
            124: "Right",
            125: "Down",
            126: "Up"
        ]

        for (keyCode, expectedName) in expectedNames {
            #expect(
                KeyboardKey.make(
                    keyCode: keyCode,
                    charactersIgnoringModifiers: nil
                ).displayName == expectedName
            )
        }
    }

    @Test func ordinaryAndUnknownKeysHaveDeterministicFallbackNames() {
        #expect(
            KeyboardKey.make(
                keyCode: 13,
                charactersIgnoringModifiers: "w"
            ).displayName == "W"
        )
        #expect(
            KeyboardKey.make(
                keyCode: 200,
                charactersIgnoringModifiers: nil
            ).displayName == "Key200"
        )
    }

    @Test func sortingUsesDisplayNameThenKeyCode() {
        let keys = [
            KeyboardKey(keyCode: 2, displayName: "B"),
            KeyboardKey(keyCode: 9, displayName: "A"),
            KeyboardKey(keyCode: 3, displayName: "A")
        ]

        #expect(keys.sorted().map(\.keyCode) == [3, 9, 2])
    }
}
