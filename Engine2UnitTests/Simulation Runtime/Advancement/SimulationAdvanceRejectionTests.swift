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

    @Test func activeAuthorityCarriesTheUnchangedCurrentCursor() {
        let current = SimulationCursor(
            sessionID: SimulationSessionID(
                rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000016")!
            ),
            tick: SimulationTick(rawValue: 7)
        )
        let rejection = SimulationAdvanceRejection.advanceAuthorityActive(
            current: current
        )

        guard case let .advanceAuthorityActive(actualCurrent) = rejection else {
            Issue.record("Expected an active advance-authority rejection")
            return
        }

        #expect(actualCurrent == current)
        requireSendable(rejection)
    }

    private func requireSendable(_ value: some Sendable) {}
}
