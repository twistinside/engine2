import Engine2
import Engine2AssemblySupport
/// Complete terminal from selecting and deriving one live real-time snapshot.
///
/// Every output-stage terminal retains the exact immutable presentation selected
/// before rendering began. Later Simulation ticks or a subsequent session
/// rebuild cannot alter the source carried by this outcome.
nonisolated enum RealtimeSnapshotCaptureOutcome: Equatable, Sendable {
    case cancelledAfterRender(sourceSnapshot: SimulationPresentationSnapshot, renderResult: OffscreenRenderResult)
    case cancelledBeforeRender
    case completed(sourceSnapshot: SimulationPresentationSnapshot, artifact: RenderedImageArtifact)
    case connectionBusy
    case artifactEncodingFailed(
        sourceSnapshot: SimulationPresentationSnapshot,
        renderResult: OffscreenRenderResult,
        failure: ImageArtifactEncoderError
    )
    case artifactResultMismatch(
        sourceSnapshot: SimulationPresentationSnapshot,
        renderResult: OffscreenRenderResult,
        artifact: RenderedImageArtifact
    )
    case renderCancellationRequestIDMismatch(
        sourceSnapshot: SimulationPresentationSnapshot,
        expectedRequestID: OffscreenRenderRequestID,
        actualRequestID: OffscreenRenderRequestID
    )
    case renderCancelledAfterSubmission(sourceSnapshot: SimulationPresentationSnapshot, requestID: OffscreenRenderRequestID)
    case renderFailed(sourceSnapshot: SimulationPresentationSnapshot, failure: OffscreenRenderFailure)
    case renderRejected(sourceSnapshot: SimulationPresentationSnapshot, rejection: OffscreenRenderRejection)
    case renderResultMismatch(sourceSnapshot: SimulationPresentationSnapshot, renderResult: OffscreenRenderResult)

    /// Adds the exact selected live publication to one shared artifact terminal.
    init(
        artifactOutcome: OffscreenImageArtifactOutcome,
        sourceSnapshot: SimulationPresentationSnapshot
    ) {
        switch artifactOutcome {
        case let .completed(artifact):
            self = .completed(
                sourceSnapshot: sourceSnapshot,
                artifact: artifact
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
}
