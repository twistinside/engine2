/// Source-independent terminal from one exact offscreen render and JPEG derivation.
///
/// The outcome retains the raw result whenever rendering completed but artifact
/// derivation did not. Callers can therefore retry JPEG encoding without
/// resampling Simulation, resolving another viewpoint, or submitting GPU work.
nonisolated enum OffscreenJPEGArtifactOutcome: Equatable, Sendable {
    case completed(RenderedImageArtifact)
    case renderRejected(OffscreenRenderRejection)
    case renderFailed(OffscreenRenderFailure)
    case renderCancellationRequestIDMismatch(
        expectedRequestID: OffscreenRenderRequestID,
        actualRequestID: OffscreenRenderRequestID
    )
    case renderCancelledAfterSubmission(OffscreenRenderRequestID)
    case renderResultMismatch(OffscreenRenderResult)
    case cancelledAfterRender(OffscreenRenderResult)
    case jpegEncodingFailed(
        renderResult: OffscreenRenderResult,
        failure: JPEGArtifactEncoderError
    )
}
