/// Complete terminal from selecting and deriving one live real-time snapshot.
///
/// Every output-stage terminal retains the exact immutable presentation selected
/// before rendering began. Later Simulation ticks or a subsequent session
/// rebuild cannot alter the source carried by this outcome.
nonisolated enum RealtimeSnapshotCaptureOutcome: Equatable, Sendable {
    case completed(
        sourceSnapshot: SimulationPresentationSnapshot,
        artifact: RenderedImageArtifact
    )
    case connectionBusy
    case cancelledBeforeRender
    case renderRejected(
        sourceSnapshot: SimulationPresentationSnapshot,
        rejection: OffscreenRenderRejection
    )
    case renderFailed(
        sourceSnapshot: SimulationPresentationSnapshot,
        failure: OffscreenRenderFailure
    )
    case renderCancellationRequestIDMismatch(
        sourceSnapshot: SimulationPresentationSnapshot,
        expectedRequestID: OffscreenRenderRequestID,
        actualRequestID: OffscreenRenderRequestID
    )
    case renderCancelledAfterSubmission(
        sourceSnapshot: SimulationPresentationSnapshot,
        requestID: OffscreenRenderRequestID
    )
    case renderResultMismatch(
        sourceSnapshot: SimulationPresentationSnapshot,
        renderResult: OffscreenRenderResult
    )
    case cancelledAfterRender(
        sourceSnapshot: SimulationPresentationSnapshot,
        renderResult: OffscreenRenderResult
    )
    case jpegEncodingFailed(
        sourceSnapshot: SimulationPresentationSnapshot,
        renderResult: OffscreenRenderResult,
        failure: JPEGArtifactEncoderError
    )
}
