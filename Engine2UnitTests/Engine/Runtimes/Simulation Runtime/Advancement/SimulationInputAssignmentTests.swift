import simd
import Testing
@testable import Engine2

struct SimulationInputAssignmentTests {
    @Test func distinguishesNoInputIngestionAndRebasing() {
        let publication = InputSnapshot(
            revision: InputRevision(session: 4, sequence: 12),
            translation: SIMD2<Float>(1, 0),
            isInteractionActive: true,
            cameraOrbitTotal: SIMD2<Float>(0.08, -0.02),
            cameraZoomTotal: 0.28,
            latestSelectionPress: nil,
            selectionPressCount: 0,
            firePressCount: 0
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
            revision: .init(advancing: baseline.revision),
            translation: .zero,
            isInteractionActive: false,
            cameraOrbitTotal: SIMD2<Float>(0.04, 0.02),
            cameraZoomTotal: 0,
            latestSelectionPress: nil,
            selectionPressCount: 0,
            firePressCount: 0
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
