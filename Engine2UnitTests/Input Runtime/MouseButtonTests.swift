import Testing
@testable import Engine2

struct MouseButtonTests {
    @Test func displayNamesCoverStandardAndOpenEndedButtons() {
        #expect(MouseButton.left.displayName == "LMB")
        #expect(MouseButton.right.displayName == "RMB")
        #expect(MouseButton.middle.displayName == "MMB")
        #expect(MouseButton.other(0).displayName == "M0")
        #expect(MouseButton.other(27).displayName == "M27")
    }

    @Test func sortingKeepsStandardButtonsAheadOfOrdinaryExtendedButtons() {
        let buttons: [MouseButton] = [.other(9), .middle, .other(0), .right, .left]

        #expect(buttons.sorted() == [.left, .right, .middle, .other(0), .other(9)])
    }

    @Test func extendedButtonNumberParticipatesInIdentityAndHashing() {
        let buttons: Set<MouseButton> = [.other(3), .other(3), .other(4), .left]

        #expect(buttons.count == 3)
        #expect(buttons.contains(.other(3)))
        #expect(buttons.contains(.other(4)))
    }
}
