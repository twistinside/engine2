import Foundation
import Testing
@testable import Engine2

struct SimulationAdvanceResultTests {
    @Test func correlatesCommittedRangeWithFinalSnapshot() {
        let sessionID = SimulationSessionID(
            rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000012")!
        )
        let initialCursor = SimulationCursor(
            sessionID: sessionID,
            tick: SimulationTick(rawValue: 5)
        )
        let finalCursor = SimulationCursor(
            sessionID: sessionID,
            tick: SimulationTick(rawValue: 8)
        )
        let snapshot = SimulationPresentationSnapshot(
            cursor: finalCursor,
            camera: Camera(),
            entityPresentations: []
        )

        let result = SimulationAdvanceResult(
            initialCursor: initialCursor,
            finalCursor: finalCursor,
            completedStepCount: SimulationCompletedStepCount(rawValue: 3),
            finalPresentationSnapshot: snapshot
        )

        #expect(result.initialCursor == initialCursor)
        #expect(result.finalCursor == finalCursor)
        #expect(result.completedStepCount.rawValue == 3)
        #expect(result.finalPresentationSnapshot == snapshot)
        requireSendable(result)
    }

    private func requireSendable(_ value: some Sendable) {}
}
