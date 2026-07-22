import Foundation
import Testing
@testable import Engine2

struct PSimulationAdvanceTargetTests {
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
        let target: any PSimulationAdvanceTarget = RejectionAdvanceTarget(
            rejection: rejection
        )
        let request = SimulationAdvanceRequest(
            expectedCursor: expected,
            stepCount: .one
        )

        let outcome = await target.advance(request)

        #expect(outcome == .rejected(rejection))
    }
}

private actor RejectionAdvanceTarget: PSimulationAdvanceTarget {
    let rejection: SimulationAdvanceRejection

    init(rejection: SimulationAdvanceRejection) {
        self.rejection = rejection
    }

    func advance(_ request: SimulationAdvanceRequest) async -> SimulationAdvanceOutcome {
        .rejected(rejection)
    }
}
