/// Complete outcome of one serial offline advance-render-encode workflow.
///
/// Cases before advancement contain no committed Simulation result. Every case
/// after a completed advance carries that exact ``SimulationAdvanceResult`` so
/// cancellation or downstream failure can never obscure authoritative progress
/// or tempt a caller to repeat the advance silently.
nonisolated enum OfflineCaptureOutcome: Equatable, Sendable {
    /// Simulation, raw rendering, and JPEG encoding all completed.
    case completed(OfflineCaptureResult)

    /// Another request currently owns the coordinator's complete workflow.
    case coordinatorBusy

    /// The caller cancelled before any Simulation request was issued.
    case cancelledBeforeAdvance

    /// Simulation refused the exact request without mutating its world.
    case advanceRejected(SimulationAdvanceRejection)

    /// Simulation committed, but cancellation prevented rendering from starting.
    case cancelledAfterAdvance(SimulationAdvanceResult)

    /// Render refused before GPU submission after Simulation had committed.
    case renderRejected(
        advanceResult: SimulationAdvanceResult,
        rejection: OffscreenRenderRejection
    )

    /// Render accepted the request but failed before producing a raw image.
    case renderFailed(
        advanceResult: SimulationAdvanceResult,
        failure: OffscreenRenderFailure
    )

    /// GPU work completed and released its resources after caller cancellation.
    case renderCancelledAfterSubmission(
        advanceResult: SimulationAdvanceResult,
        requestID: OffscreenRenderRequestID
    )

    /// A target returned a completed value that did not echo the exact request.
    case renderResultMismatch(
        advanceResult: SimulationAdvanceResult,
        renderResult: OffscreenRenderResult
    )

    /// Raw rendering completed, but cancellation prevented JPEG encoding.
    ///
    /// Retaining the raw result permits artifact encoding to be retried without
    /// either rerendering or advancing Simulation again.
    case cancelledAfterRender(
        advanceResult: SimulationAdvanceResult,
        renderResult: OffscreenRenderResult
    )

    /// JPEG derivation failed without changing either completed predecessor.
    ///
    /// Both immutable inputs remain available for a caller-selected encoding
    /// retry that does not rerender or advance Simulation again.
    case jpegEncodingFailed(
        advanceResult: SimulationAdvanceResult,
        renderResult: OffscreenRenderResult,
        failure: JPEGArtifactEncoderError
    )
}
