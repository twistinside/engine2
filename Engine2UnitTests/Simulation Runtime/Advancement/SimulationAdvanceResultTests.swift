import Foundation
import Testing
@testable import Engine2

struct SimulationAdvanceResultTests {
    @Test func correlatesCommittedRangeWithFinalSnapshot() {
        let rawSessionID = UUID(uuidString: "00000000-0000-0000-0000-000000000012")!
        let sessionID = SimulationSessionID(
            rawValue: rawSessionID
        )
        let initialTick = SimulationTick(rawValue: 5)
        let initialCursor = SimulationCursor(
            sessionID: sessionID,
            tick: initialTick
        )
        let finalTick = SimulationTick(rawValue: 8)
        let finalCursor = SimulationCursor(
            sessionID: sessionID,
            tick: finalTick
        )
        let snapshot = SimulationPresentationSnapshot(
            cursor: finalCursor,
            camera: .standard,
            entityPresentations: []
        )
        let completedStepCount = SimulationCompletedStepCount(rawValue: 3)

        let result = SimulationAdvanceResult(
            initialCursor: initialCursor,
            finalCursor: finalCursor,
            completedStepCount: completedStepCount,
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
