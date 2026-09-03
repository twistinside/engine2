import Foundation
import Testing
@testable import Engine2

struct SimulationAdvanceTargetTests {
    @Test func asyncCapabilityCanBeImplementedByAnIsolatedTarget() async {
        let sessionID = SimulationSessionID(
            rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000015")!
        )
        let expected = SimulationCursor(sessionID: sessionID, tick: .zero)
        let current = expected.advanced()
        let rejection = SimulationAdvanceRejection.cursorMismatch(
            expected: expected,
            current: current
        )
        let target: any SimulationAdvanceTarget = RejectionAdvanceTarget(
            rejection: rejection
        )
        let request = SimulationAdvanceRequest(
            expectedCursor: expected,
            stepCount: .one,
            inputAssignment: .none
        )

        let outcome = await target.advance(request)

        #expect(outcome == .rejected(rejection))
    }
}

private extension SimulationAdvanceTargetTests {
    private actor RejectionAdvanceTarget: SimulationAdvanceTarget {
        let rejection: SimulationAdvanceRejection

        init(rejection: SimulationAdvanceRejection) {
            self.rejection = rejection
        }

        func advance(_ request: SimulationAdvanceRequest) async -> SimulationAdvanceOutcome {
            .rejected(rejection)
        }
    }
}
