/// Source-independent terminal from one exact render-and-JPEG derivation.
///
/// `OfflineCaptureCoordinator` uses this focused internal vocabulary to apply
/// identical correlation, cancellation, and raw-result retention policy to an
/// advanced presentation and to its already completed current presentation.
nonisolated enum OfflineImageDerivationOutcome: Equatable, Sendable {
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
