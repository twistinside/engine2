/// Completion failures reported by a test-only Metal 4 submission.
///
/// A host-side wait timeout and a completed GPU workload with an execution
/// error are different failures. Keeping both explicit prevents offscreen
/// tests from reading stale attachments or reusing resources whose work may
/// still be live.
enum MetalOffscreenTestSubmissionError: Error {
    case timedOut
    case gpuExecutionFailed(any Error)
}
