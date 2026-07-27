import simd
import Testing
@testable import Engine2

struct SimulationInputAssignmentTests {
    @Test func distinguishesNoInputIngestionAndRebasing() {
        let publication = InputSnapshot(
            revision: InputRevision(session: 4, sequence: 12),
            pointerPosition: SIMD2<Float>(3, 5),
            pointerMotionTotal: SIMD2<Float>(8, -2),
            scrollTotal: SIMD2<Float>(0, 7),
            pressedMouseButtons: [.left],
            pressedKeys: []
        )

        let ingest = SimulationInputAssignment.ingest(publication)
        let rebase = SimulationInputAssignment.rebase(publication)

        guard case let .ingest(ingestedPublication) = ingest else {
            Issue.record("Expected an ingestion assignment")
            return
        }
        guard case let .rebase(rebasedPublication) = rebase else {
            Issue.record("Expected a rebase assignment")
            return
        }

        #expect(ingestedPublication == publication)
        #expect(rebasedPublication == publication)
        requireSendable(ingest)
    }

    @Test func transitionPreservesBothImmutableBoundaryValues() {
        let baseline = InputSnapshot.empty
        let snapshot = InputSnapshot(
            revision: baseline.revision.advanced(),
            pointerPosition: SIMD2<Float>(4, 2),
            pointerMotionTotal: SIMD2<Float>(4, 2),
            scrollTotal: .zero,
            pressedMouseButtons: [],
            pressedKeys: []
        )
        let assignment = SimulationInputAssignment.rebaseThenIngest(
            baseline: baseline,
            snapshot: snapshot
        )

        guard case let .rebaseThenIngest(
            capturedBaseline,
            capturedSnapshot
        ) = assignment else {
            Issue.record("Expected a transition input assignment.")
            return
        }

        #expect(capturedBaseline == baseline)
        #expect(capturedSnapshot == snapshot)
        requireSendable(assignment)
    }

    private func requireSendable(_ value: some Sendable) {}
}
