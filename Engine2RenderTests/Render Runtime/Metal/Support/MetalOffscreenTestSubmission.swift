import Dispatch
import Foundation

/// Retains an offscreen test submission independently of its timeout waiter.
///
/// A timeout reports a test failure but does not prove the GPU has stopped
/// referencing Metal 4 resources. Queue feedback captures this token, keeping
/// every supplied owner alive until actual GPU completion even if the test
/// function has already returned.
nonisolated final class MetalOffscreenTestSubmission: @unchecked Sendable {
    private let retainedObjects: [AnyObject]
    private let completion = DispatchSemaphore(value: 0)
    private let stateLock = NSLock()
    private var feedbackError: (any Error)?

    init(retaining retainedObjects: [AnyObject]) {
        precondition(
            !retainedObjects.isEmpty,
            "An offscreen submission must retain at least one resource owner."
        )

        self.retainedObjects = retainedObjects
    }

    /// Stores Metal's completion status before releasing the host-side waiter.
    ///
    /// The feedback callback runs on Metal's feedback queue, while the test
    /// waits on its own executor. The lock protects the error handoff; the
    /// semaphore establishes completion without making either thread own the
    /// other's lifetime.
    func complete(feedbackError: (any Error)?) {
        stateLock.lock()
        self.feedbackError = feedbackError
        stateLock.unlock()
        completion.signal()
    }

    /// Waits for actual GPU feedback and rejects both timeout and GPU failure.
    func waitForCompletion(
        timeout: DispatchTime
    ) throws {
        guard completion.wait(timeout: timeout) == .success else {
            throw MetalOffscreenTestSubmissionError.timedOut
        }

        stateLock.lock()
        let feedbackError = self.feedbackError
        stateLock.unlock()

        if let feedbackError {
            throw MetalOffscreenTestSubmissionError.gpuExecutionFailed(
                feedbackError
            )
        }
    }
}
