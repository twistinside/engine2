import Foundation
import Testing
@testable import Engine2

struct MetalRenderErrorStateTests {
    @Test func beginsWithoutARecordedFailure() {
        let state = MetalRenderErrorState()

        #expect(state.latestError == nil)
    }

    @Test func successfulFeedbackDoesNotCreateOrClearAnError() throws {
        let state = MetalRenderErrorState()

        // A nil feedback error represents successful completion. It must remain
        // a no-op both before and after a real failure so later successes cannot
        // erase the diagnostic that stopped renderer submission.
        state.record(nil)
        #expect(state.latestError == nil)

        let expected = NSError(
            domain: "MetalRenderErrorStateTests",
            code: 17
        )
        state.record(expected)
        state.record(nil)

        let recorded = try #require(state.latestError as? NSError)
        #expect(recorded === expected)
    }

    @Test func aLaterFailureReplacesTheLatestRecordedFailure() throws {
        let state = MetalRenderErrorState()
        let first = NSError(
            domain: "MetalRenderErrorStateTests.first",
            code: 1
        )
        let second = NSError(
            domain: "MetalRenderErrorStateTests.second",
            code: 2
        )

        // The state is sticky across successful submissions, but its public name
        // and contract are intentionally "latest error." If multiple failures
        // are explicitly recorded, diagnostics should expose the newest one.
        state.record(first)
        state.record(second)

        let recorded = try #require(state.latestError as? NSError)
        #expect(recorded === second)
    }

    @Test func submissionActionRunsOnlyWhileStateIsHealthy() {
        let state = MetalRenderErrorState()
        var actionCount = 0

        let firstResult = state.performIfHealthy {
            actionCount += 1
        }
        state.record(
            NSError(domain: "MetalRenderErrorStateTests.terminal", code: 3)
        )
        let secondResult = state.performIfHealthy {
            actionCount += 1
        }

        #expect(firstResult)
        #expect(!secondResult)
        #expect(actionCount == 1)
    }
}
