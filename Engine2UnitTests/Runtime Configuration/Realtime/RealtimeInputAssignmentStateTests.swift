import Testing
@testable import Engine2
@testable import Engine2RealtimeAssembly

struct RealtimeInputAssignmentStateTests {
    @Test func noBaselineAndNoPublicationProduceNoInputWork() {
        let state = RealtimeInputAssignmentState()

        guard case .none = state.assignment(ingesting: nil) else {
            Issue.record("Expected an empty input assignment.")
            return
        }
    }

    @Test func latestPublicationWithoutABaselineIsIngested() {
        let state = RealtimeInputAssignmentState()
        let snapshot = makeSnapshot(sequence: 1)

        guard case let .ingest(actual) = state.assignment(ingesting: snapshot) else {
            Issue.record("Expected the latest publication to be ingested.")
            return
        }
        #expect(actual == snapshot)
    }

    @Test func baselineWithoutALaterPublicationIsRebased() {
        var state = RealtimeInputAssignmentState()
        let baseline = makeSnapshot(sequence: 1)
        state.replaceTransitionBaseline(baseline)

        guard case let .rebase(actual) = state.assignment(ingesting: nil) else {
            Issue.record("Expected the transition baseline to be installed.")
            return
        }
        #expect(actual == baseline)
    }

    @Test func baselineAndLaterPublicationTravelAsOneTransition() {
        var state = RealtimeInputAssignmentState()
        let baseline = makeSnapshot(sequence: 1)
        let snapshot = makeSnapshot(sequence: 2)
        state.replaceTransitionBaseline(baseline)

        guard case let .rebaseThenIngest(actualBaseline, actualSnapshot) = state.assignment(ingesting: snapshot) else {
            Issue.record("Expected one atomic rebase-then-ingest assignment.")
            return
        }
        #expect(actualBaseline == baseline)
        #expect(actualSnapshot == snapshot)
    }

    @Test func completionRetiresTheExactBaselineGenerationItObserved() {
        var state = RealtimeInputAssignmentState()
        state.replaceTransitionBaseline(makeSnapshot(sequence: 1))
        let requestState = state

        state.retireTransitionBaseline(ifUnchangedSince: requestState)

        guard case .none = state.assignment(ingesting: nil) else {
            Issue.record("Expected the committed baseline to be retired.")
            return
        }
    }

    @Test func equalNewerPolicySupersedesStaleRequestBookkeeping() {
        var state = RealtimeInputAssignmentState()
        let baseline = makeSnapshot(sequence: 1)
        state.replaceTransitionBaseline(baseline)
        let staleRequestState = state
        state.replaceTransitionBaseline(baseline)

        state.retireTransitionBaseline(ifUnchangedSince: staleRequestState)

        guard case let .rebase(actual) = state.assignment(ingesting: nil) else {
            Issue.record("Expected newer policy to preserve its baseline.")
            return
        }
        #expect(actual == baseline)
    }

    private func makeSnapshot(sequence: UInt64) -> InputSnapshot {
        InputSnapshot(
            revision: InputRevision(session: 1, sequence: sequence),
            pointerPosition: .zero,
            pointerMotionTotal: .zero,
            scrollTotal: .zero,
            pressedMouseButtons: [],
            pressedKeys: []
        )
    }
}
