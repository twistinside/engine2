/// Complete outcome of asking an offscreen render target for one exact image.
///
/// This is deliberately an explicit result instead of a throwing API. Expected
/// admission refusals and post-submission cancellation are protocol outcomes,
/// not exceptional control flow, and every case must preserve exact request
/// correlation across actor and future transport boundaries. Only the
/// unexpected accepted-request payload conforms to `Error`.
nonisolated enum OffscreenRenderOutcome: Equatable, Sendable {
    case completed(OffscreenRenderResult)
    case rejected(OffscreenRenderRejection)
    case failed(OffscreenRenderFailure)

    /// GPU work reached completion and released its resources after the caller
    /// cancelled, so no detached CPU image was allocated or returned.
    case cancelledAfterSubmission(requestID: OffscreenRenderRequestID)
}
