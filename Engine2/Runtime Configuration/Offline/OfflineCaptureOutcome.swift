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

    /// Simulation reported a coherent completion that did not match the
    /// coordinator's retained starting cursor or the submitted request.
    ///
    /// The target may already have committed the returned range. The
    /// coordinator therefore retains `result.finalPresentationSnapshot` as its
    /// new current value and exposes the complete correlation failure without
    /// rendering or pretending that the requested operation completed exactly.
    case advanceResultMismatch(
        coordinatorCursor: SimulationCursor,
        requestedExpectedCursor: SimulationCursor?,
        requestedStepCount: SimulationStepCount,
        result: SimulationAdvanceResult
    )

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

    /// Render reported post-submission cancellation for a different request.
    ///
    /// Treating the backend's actual identity as this capture's identity would
    /// corrupt correlation, so both values remain explicit for diagnosis.
    case renderCancellationRequestIDMismatch(
        advanceResult: SimulationAdvanceResult,
        expectedRequestID: OffscreenRenderRequestID,
        actualRequestID: OffscreenRenderRequestID
    )

    /// GPU work completed and released its resources after caller cancellation.
    case renderCancelledAfterSubmission(
        advanceResult: SimulationAdvanceResult,
        requestID: OffscreenRenderRequestID
    )

    /// A completed value did not echo the exact request and image extent.
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
