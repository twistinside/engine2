import Foundation
import Testing
@testable import Engine2

struct SimulationAdvanceOutcomeTests {
    @Test func completedAndRejectedRemainDistinct() {
        let sessionID = SimulationSessionID(
            rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000014")!
        )
        let initialCursor = SimulationCursor(sessionID: sessionID, tick: .zero)
        let finalCursor = initialCursor.advanced()
        let result = SimulationAdvanceResult(
            initialCursor: initialCursor,
            finalCursor: finalCursor,
            completedStepCount: SimulationCompletedStepCount(rawValue: 1),
            finalPresentationSnapshot: SimulationPresentationSnapshot(
                cursor: finalCursor,
                camera: Camera(),
                entityPresentations: []
            )
        )
        let rejection = SimulationAdvanceRejection.cursorMismatch(
            expected: initialCursor,
            current: finalCursor
        )

        let completed = SimulationAdvanceOutcome.completed(result)
        let rejected = SimulationAdvanceOutcome.rejected(rejection)

        #expect(completed == .completed(result))
        #expect(rejected == .rejected(rejection))
        #expect(completed != rejected)
        requireSendable(completed)
        requireSendable(rejected)
    }

    private func requireSendable(_ value: some Sendable) {}
}
