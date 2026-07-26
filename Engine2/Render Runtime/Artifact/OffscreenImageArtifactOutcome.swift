/// Source-independent terminal from one exact render and artifact derivation.
///
/// The outcome retains the raw result whenever rendering completed but artifact
/// derivation did not. Callers can therefore retry encoding without
/// resampling Simulation, resolving another viewpoint, or submitting GPU work.
nonisolated enum OffscreenImageArtifactOutcome: Equatable, Sendable {
    case artifactEncodingFailed(renderResult: OffscreenRenderResult, failure: ImageArtifactEncoderError)
    /// Encoding returned empty bytes or provenance that did not match its input.
    case artifactResultMismatch(renderResult: OffscreenRenderResult, artifact: RenderedImageArtifact)
    case cancelledAfterRender(OffscreenRenderResult)
    case completed(RenderedImageArtifact)
    case renderCancellationRequestIDMismatch(
        expectedRequestID: OffscreenRenderRequestID,
        actualRequestID: OffscreenRenderRequestID
    )
    case renderCancelledAfterSubmission(OffscreenRenderRequestID)
    case renderFailed(OffscreenRenderFailure)
    case renderRejected(OffscreenRenderRejection)
    case renderResultMismatch(OffscreenRenderResult)
}
