import Engine2
import Engine2AssemblySupport
/// Complete outcome of one serial offline advance-render-encode workflow.
///
/// Cases before advancement contain no committed Simulation result. Every case
/// after a completed advance carries that exact ``SimulationAdvanceResult`` so
/// cancellation or downstream failure can never obscure authoritative progress
/// or tempt a caller to repeat the advance silently.
public nonisolated enum OfflineCaptureOutcome: Equatable, Sendable {
    /// Simulation, raw rendering, and artifact encoding all completed.
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
    case renderRejected(advanceResult: SimulationAdvanceResult, rejection: OffscreenRenderRejection)

    /// Render accepted the request but failed before producing a raw image.
    case renderFailed(advanceResult: SimulationAdvanceResult, failure: OffscreenRenderFailure)

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
    case renderCancelledAfterSubmission(advanceResult: SimulationAdvanceResult, requestID: OffscreenRenderRequestID)

    /// A completed value did not echo the exact request and image extent.
    case renderResultMismatch(advanceResult: SimulationAdvanceResult, renderResult: OffscreenRenderResult)

    /// Raw rendering completed, but cancellation prevented artifact encoding.
    ///
    /// Retaining the raw result permits artifact encoding to be retried without
    /// either rerendering or advancing Simulation again.
    case cancelledAfterRender(advanceResult: SimulationAdvanceResult, renderResult: OffscreenRenderResult)

    /// Artifact derivation failed without changing either completed predecessor.
    ///
    /// Both immutable inputs remain available for a caller-selected encoding
    /// retry that does not rerender or advance Simulation again.
    case artifactEncodingFailed(
        advanceResult: SimulationAdvanceResult,
        renderResult: OffscreenRenderResult,
        failure: ImageArtifactEncoderError
    )

    /// The encoder returned empty bytes or mismatched exact provenance.
    ///
    /// Both the raw result and invalid artifact are retained for diagnosis;
    /// callers must not accept the encoded bytes as this request's output.
    case artifactResultMismatch(
        advanceResult: SimulationAdvanceResult,
        renderResult: OffscreenRenderResult,
        artifact: RenderedImageArtifact
    )

    /// Projects a shared artifact terminal into the advance-aware offline domain.
    ///
    /// Every terminal gains the exact committed Simulation result while all
    /// render and artifact payloads remain unchanged.
    init(artifactOutcome: OffscreenImageArtifactOutcome, advanceResult: SimulationAdvanceResult) {
        switch artifactOutcome {
        case let .completed(artifact):
            self = .completed(
                OfflineCaptureResult(
                    advanceResult: advanceResult,
                    artifact: artifact
                )
            )

        case let .renderRejected(rejection):
            self = .renderRejected(
                advanceResult: advanceResult,
                rejection: rejection
            )

        case let .renderFailed(failure):
            self = .renderFailed(
                advanceResult: advanceResult,
                failure: failure
            )

        case let .renderCancellationRequestIDMismatch(expected, actual):
            self = .renderCancellationRequestIDMismatch(
                advanceResult: advanceResult,
                expectedRequestID: expected,
                actualRequestID: actual
            )

        case let .renderCancelledAfterSubmission(requestID):
            self = .renderCancelledAfterSubmission(
                advanceResult: advanceResult,
                requestID: requestID
            )

        case let .renderResultMismatch(renderResult):
            self = .renderResultMismatch(
                advanceResult: advanceResult,
                renderResult: renderResult
            )

        case let .cancelledAfterRender(renderResult):
            self = .cancelledAfterRender(
                advanceResult: advanceResult,
                renderResult: renderResult
            )

        case let .artifactEncodingFailed(renderResult, failure):
            self = .artifactEncodingFailed(
                advanceResult: advanceResult,
                renderResult: renderResult,
                failure: failure
            )

        case let .artifactResultMismatch(renderResult, artifact):
            self = .artifactResultMismatch(
                advanceResult: advanceResult,
                renderResult: renderResult,
                artifact: artifact
            )
        }
    }

    /// Returns the authoritative Simulation cursor established by this outcome.
    ///
    /// Outcomes that observe no Simulation work retain `previous`. A rejection
    /// reports the target's current cursor, and every post-advance terminal
    /// reports the exact committed result's final cursor.
    public func authoritativeCursor(
        after previous: SimulationCursor
    ) -> SimulationCursor {
        switch self {
        case let .completed(result):
            result.advanceResult.finalCursor

        case .coordinatorBusy,
             .cancelledBeforeAdvance:
            previous

        case let .advanceRejected(.cursorMismatch(_, current)):
            current

        case let .advanceResultMismatch(_, _, _, result),
             let .cancelledAfterAdvance(result),
             let .renderRejected(result, _),
             let .renderFailed(result, _),
             let .renderCancellationRequestIDMismatch(result, _, _),
             let .renderCancelledAfterSubmission(result, _),
             let .renderResultMismatch(result, _),
             let .cancelledAfterRender(result, _),
             let .artifactEncodingFailed(result, _, _),
             let .artifactResultMismatch(result, _, _):
            result.finalCursor
        }
    }
}
