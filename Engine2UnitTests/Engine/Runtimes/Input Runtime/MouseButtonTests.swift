import Testing
@testable import Engine2

struct MouseButtonTests {
    @Test func extendedButtonNumberParticipatesInIdentityAndHashing() {
        let buttons: Set<MouseButton> = [.other(3), .other(3), .other(4), .left]

        #expect(buttons.count == 3)
        #expect(buttons.contains(.other(3)))
        #expect(buttons.contains(.other(4)))
    }
}
