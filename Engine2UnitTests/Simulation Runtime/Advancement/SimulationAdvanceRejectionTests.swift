import Foundation
import Testing
@testable import Engine2

struct SimulationAdvanceRejectionTests {
    @Test func cursorMismatchCarriesExpectedAndCurrentPositions() {
        let sessionID = SimulationSessionID(
            rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000013")!
        )
        let expected = SimulationCursor(
            sessionID: sessionID,
            tick: SimulationTick(rawValue: 2)
        )
        let current = SimulationCursor(
            sessionID: sessionID,
            tick: SimulationTick(rawValue: 4)
        )
        let rejection = SimulationAdvanceRejection.cursorMismatch(
            expected: expected,
            current: current
        )

        guard case let .cursorMismatch(actualExpected, actualCurrent) = rejection else {
            Issue.record("Expected a cursor mismatch rejection")
            return
        }

        #expect(actualExpected == expected)
        #expect(actualCurrent == current)
        requireSendable(rejection)
    }
    private func requireSendable(_ value: some Sendable) {}
}
