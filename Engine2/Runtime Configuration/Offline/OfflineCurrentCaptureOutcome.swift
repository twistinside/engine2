/// Complete outcome of rendering and encoding the current exact presentation.
///
/// Cursor mismatch and pre-render cancellation perform no output work. Every
/// outcome after the expected cursor is validated retains that immutable
/// snapshot, and outcomes after raw rendering also retain the detached image
/// when available. No case advances Simulation, samples a latest-value source,
/// or retries work.
nonisolated enum OfflineCurrentCaptureOutcome: Equatable, Sendable {
    /// Raw rendering and JPEG encoding completed without advancing Simulation.
    case completed(OfflineCurrentCaptureResult)

    /// Another advance or current-state workflow owns the serial coordinator.
    case coordinatorBusy

    /// The caller cancelled before any render request was issued.
    case cancelledBeforeRender

    /// The retained current presentation did not match the caller's expectation.
    case cursorMismatch(
        expected: SimulationCursor,
        current: SimulationCursor
    )

    /// Render refused before GPU submission for the selected presentation.
    case renderRejected(
        sourceSnapshot: SimulationPresentationSnapshot,
        rejection: OffscreenRenderRejection
    )

    /// Render accepted the request but failed before producing a raw image.
    case renderFailed(
        sourceSnapshot: SimulationPresentationSnapshot,
        failure: OffscreenRenderFailure
    )

    /// Render reported post-submission cancellation for a different request.
    case renderCancellationRequestIDMismatch(
        sourceSnapshot: SimulationPresentationSnapshot,
        expectedRequestID: OffscreenRenderRequestID,
        actualRequestID: OffscreenRenderRequestID
    )

    /// GPU work completed and released resources after caller cancellation.
    case renderCancelledAfterSubmission(
        sourceSnapshot: SimulationPresentationSnapshot,
        requestID: OffscreenRenderRequestID
    )

    /// A completed value did not echo the exact request and image extent.
    case renderResultMismatch(
        sourceSnapshot: SimulationPresentationSnapshot,
        renderResult: OffscreenRenderResult
    )

    /// Raw rendering completed, but cancellation prevented JPEG encoding.
    case cancelledAfterRender(
        sourceSnapshot: SimulationPresentationSnapshot,
        renderResult: OffscreenRenderResult
    )

    /// JPEG derivation failed without changing either completed predecessor.
    case jpegEncodingFailed(
        sourceSnapshot: SimulationPresentationSnapshot,
        renderResult: OffscreenRenderResult,
        failure: JPEGArtifactEncoderError
    )
}
