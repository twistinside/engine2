/// Complete outcome of rendering and encoding the current exact presentation.
///
/// Cursor mismatch and pre-render cancellation perform no output work. Every
/// outcome after the expected cursor is validated retains that immutable
/// snapshot, and outcomes after raw rendering also retain the detached image
/// when available. No case advances Simulation, samples a latest-value source,
/// or retries work.
nonisolated enum OfflineCurrentCaptureOutcome: Equatable, Sendable {
    /// Raw rendering and artifact encoding completed without advancing Simulation.
    case completed(OfflineCurrentCaptureResult)

    /// Another advance or current-state workflow owns the serial coordinator.
    case coordinatorBusy

    /// The caller cancelled before any render request was issued.
    case cancelledBeforeRender

    /// The retained current presentation did not match the caller's expectation.
    case cursorMismatch(expected: SimulationCursor, current: SimulationCursor)

    /// Render refused before GPU submission for the selected presentation.
    case renderRejected(sourceSnapshot: SimulationPresentationSnapshot, rejection: OffscreenRenderRejection)

    /// Render accepted the request but failed before producing a raw image.
    case renderFailed(sourceSnapshot: SimulationPresentationSnapshot, failure: OffscreenRenderFailure)

    /// Render reported post-submission cancellation for a different request.
    case renderCancellationRequestIDMismatch(
        sourceSnapshot: SimulationPresentationSnapshot,
        expectedRequestID: OffscreenRenderRequestID,
        actualRequestID: OffscreenRenderRequestID
    )

    /// GPU work completed and released resources after caller cancellation.
    case renderCancelledAfterSubmission(sourceSnapshot: SimulationPresentationSnapshot, requestID: OffscreenRenderRequestID)

    /// A completed value did not echo the exact request and image extent.
    case renderResultMismatch(sourceSnapshot: SimulationPresentationSnapshot, renderResult: OffscreenRenderResult)

    /// Raw rendering completed, but cancellation prevented artifact encoding.
    case cancelledAfterRender(sourceSnapshot: SimulationPresentationSnapshot, renderResult: OffscreenRenderResult)

    /// Artifact derivation failed without changing either completed predecessor.
    case artifactEncodingFailed(
        sourceSnapshot: SimulationPresentationSnapshot,
        renderResult: OffscreenRenderResult,
        failure: ImageArtifactEncoderError
    )

    /// The encoder returned empty bytes or attribution for another operation.
    case artifactResultMismatch(
        sourceSnapshot: SimulationPresentationSnapshot,
        renderResult: OffscreenRenderResult,
        artifact: RenderedImageArtifact
    )

    /// Projects a shared artifact terminal into the current-capture domain.
    ///
    /// Every terminal gains the exact selected presentation while all render
    /// and artifact payloads remain unchanged.
    init(artifactOutcome: OffscreenImageArtifactOutcome, sourceSnapshot: SimulationPresentationSnapshot) {
        switch artifactOutcome {
        case let .completed(artifact):
            self = .completed(
                OfflineCurrentCaptureResult(
                    sourceSnapshot: sourceSnapshot,
                    artifact: artifact
                )
            )

        case let .renderRejected(rejection):
            self = .renderRejected(
                sourceSnapshot: sourceSnapshot,
                rejection: rejection
            )

        case let .renderFailed(failure):
            self = .renderFailed(
                sourceSnapshot: sourceSnapshot,
                failure: failure
            )

        case let .renderCancellationRequestIDMismatch(expected, actual):
            self = .renderCancellationRequestIDMismatch(
                sourceSnapshot: sourceSnapshot,
                expectedRequestID: expected,
                actualRequestID: actual
            )

        case let .renderCancelledAfterSubmission(requestID):
            self = .renderCancelledAfterSubmission(
                sourceSnapshot: sourceSnapshot,
                requestID: requestID
            )

        case let .renderResultMismatch(renderResult):
            self = .renderResultMismatch(
                sourceSnapshot: sourceSnapshot,
                renderResult: renderResult
            )

        case let .cancelledAfterRender(renderResult):
            self = .cancelledAfterRender(
                sourceSnapshot: sourceSnapshot,
                renderResult: renderResult
            )

        case let .artifactEncodingFailed(renderResult, failure):
            self = .artifactEncodingFailed(
                sourceSnapshot: sourceSnapshot,
                renderResult: renderResult,
                failure: failure
            )

        case let .artifactResultMismatch(renderResult, artifact):
            self = .artifactResultMismatch(
                sourceSnapshot: sourceSnapshot,
                renderResult: renderResult,
                artifact: artifact
            )
        }
    }

    /// Returns the authoritative Simulation cursor established by this outcome.
    ///
    /// Outcomes that observe no selected presentation retain `previous`. A
    /// cursor mismatch reports the target's current cursor, and every terminal
    /// after selection reports that exact immutable snapshot's cursor.
    func authoritativeCursor(after previous: SimulationCursor) -> SimulationCursor {
        switch self {
        case let .completed(result):
            result.sourceSnapshot.cursor

        case .coordinatorBusy,
             .cancelledBeforeRender:
            previous

        case let .cursorMismatch(_, current):
            current

        case let .renderRejected(sourceSnapshot, _),
             let .renderFailed(sourceSnapshot, _),
             let .renderCancellationRequestIDMismatch(sourceSnapshot, _, _),
             let .renderCancelledAfterSubmission(sourceSnapshot, _),
             let .renderResultMismatch(sourceSnapshot, _),
             let .cancelledAfterRender(sourceSnapshot, _),
             let .artifactEncodingFailed(sourceSnapshot, _, _),
             let .artifactResultMismatch(sourceSnapshot, _, _):
            sourceSnapshot.cursor
        }
    }
}
