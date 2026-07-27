import Dispatch
import Foundation
import Testing

struct MetalOffscreenTestSubmissionTests {
    @Test func successfulFeedbackReleasesTheWaiter() throws {
        let retainedOwner = NSObject()
        let submission = MetalOffscreenTestSubmission(
            retaining: [retainedOwner]
        )

        submission.complete(feedbackError: nil)

        try submission.waitForCompletion(timeout: .now())
    }

    @Test func gpuFeedbackErrorIsPropagated() {
        let retainedOwner = NSObject()
        let submission = MetalOffscreenTestSubmission(
            retaining: [retainedOwner]
        )
        let expectedError = NSError(
            domain: "MetalOffscreenTestSubmissionTests",
            code: 17
        )

        submission.complete(feedbackError: expectedError)

        do {
            try submission.waitForCompletion(timeout: .now())
            Issue.record("Expected the captured GPU feedback error.")
        } catch MetalOffscreenTestSubmissionError.gpuExecutionFailed(
            let error
        ) {
            let actualError = error as NSError
            #expect(actualError.domain == expectedError.domain)
            #expect(actualError.code == expectedError.code)
        } catch {
            Issue.record("Unexpected completion error: \(error)")
        }
    }

    @Test func missingFeedbackIsReportedAsTimeout() {
        let retainedOwner = NSObject()
        let submission = MetalOffscreenTestSubmission(
            retaining: [retainedOwner]
        )

        do {
            try submission.waitForCompletion(timeout: .now())
            Issue.record("Expected a host-side feedback timeout.")
        } catch MetalOffscreenTestSubmissionError.timedOut {
            // This is the only expected failure mode when no callback fires.
        } catch {
            Issue.record("Unexpected completion error: \(error)")
        }
    }
}
