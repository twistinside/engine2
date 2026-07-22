/// Complete outcome of asking an offscreen render target for one exact image.
nonisolated enum OffscreenRenderOutcome: Equatable, Sendable {
    case completed(OffscreenRenderResult)
    case rejected(OffscreenRenderRejection)
    case failed(OffscreenRenderFailure)

    /// GPU work reached completion and released its resources after the caller
    /// cancelled, so no detached CPU image was allocated or returned.
    case cancelledAfterSubmission(requestID: OffscreenRenderRequestID)
}
