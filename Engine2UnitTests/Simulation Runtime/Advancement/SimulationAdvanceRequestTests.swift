import Foundation
import Testing
@testable import Engine2

struct SimulationAdvanceRequestTests {
    @Test func preservesExplicitUnconditionalAdvanceWithoutInput() {
        let stepCount = SimulationStepCount(rawValue: 3)
        let request = SimulationAdvanceRequest(
            expectedCursor: nil,
            stepCount: stepCount,
            inputAssignment: .none
        )

        #expect(request.expectedCursor == nil)
        #expect(request.stepCount.rawValue == 3)
        guard case .none = request.inputAssignment else {
            Issue.record("Expected the explicit no-input assignment")
            return
        }
        requireSendable(request)
    }

    @Test func preservesExpectedSessionQualifiedCursor() {
        let rawSessionID = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!
        let sessionID = SimulationSessionID(rawValue: rawSessionID)
        let tick = SimulationTick(rawValue: 9)
        let cursor = SimulationCursor(
            sessionID: sessionID,
            tick: tick
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
