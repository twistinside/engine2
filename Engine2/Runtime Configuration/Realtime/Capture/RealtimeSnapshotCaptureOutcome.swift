/// Complete terminal from selecting and deriving one live real-time snapshot.
///
/// Every output-stage terminal retains the exact immutable presentation selected
/// before rendering began. Later Simulation ticks or a subsequent session
/// rebuild cannot alter the source carried by this outcome.
nonisolated enum RealtimeSnapshotCaptureOutcome: Equatable, Sendable {
    case cancelledAfterRender(
        sourceSnapshot: SimulationPresentationSnapshot,
        renderResult: OffscreenRenderResult
    )
    case cancelledBeforeRender
    case completed(
        sourceSnapshot: SimulationPresentationSnapshot,
        artifact: RenderedImageArtifact
    )
    case connectionBusy
    case jpegEncodingFailed(
        sourceSnapshot: SimulationPresentationSnapshot,
        renderResult: OffscreenRenderResult,
        failure: JPEGArtifactEncoderError
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
    case renderFailed(
        sourceSnapshot: SimulationPresentationSnapshot,
        failure: OffscreenRenderFailure
    )
    case renderRejected(
        sourceSnapshot: SimulationPresentationSnapshot,
        rejection: OffscreenRenderRejection
    )
    case renderResultMismatch(
        sourceSnapshot: SimulationPresentationSnapshot,
        renderResult: OffscreenRenderResult
    )
}
