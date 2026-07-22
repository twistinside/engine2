import Foundation
import Testing
@testable import Engine2

struct SimulationAdvanceRequestTests {
    @Test func defaultsToUnconditionalAdvanceWithoutInput() {
        let request = SimulationAdvanceRequest(
            stepCount: SimulationStepCount(rawValue: 3)
        )

        #expect(request.expectedCursor == nil)
        #expect(request.stepCount.rawValue == 3)
        guard case .none = request.inputAssignment else {
            Issue.record("Expected the default no-input assignment")
            return
        }
        requireSendable(request)
    }

    @Test func preservesExpectedSessionQualifiedCursor() {
        let cursor = SimulationCursor(
            sessionID: SimulationSessionID(
                rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!
            ),
            tick: SimulationTick(rawValue: 9)
        )
        let request = SimulationAdvanceRequest(
            expectedCursor: cursor,
            stepCount: .one,
            inputAssignment: .rebase(.empty)
        )

        #expect(request.expectedCursor == cursor)
        guard case let .rebase(snapshot) = request.inputAssignment else {
            Issue.record("Expected a rebase assignment")
            return
        }
        #expect(snapshot == .empty)
    }

    private func requireSendable(_ value: some Sendable) {}
}
