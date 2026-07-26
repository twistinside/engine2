/// Terminal result of one accepted and sequence-consuming agent request.
///
/// Both capture forms consume the same monotonic identity even though only an
/// advancing source can change the authoritative Simulation cursor.
nonisolated enum AgentSessionExecutionOutcome: Equatable, Sendable {
    /// Exact terminal output from an advance-then-capture workflow.
    case capture(OfflineCaptureOutcome)

    /// Exact terminal output from capture of an already completed cursor.
    case currentCapture(OfflineCurrentCaptureOutcome)

    /// The identity was accepted but its requested batch exceeded session policy.
    ///
    /// This result is retained and replayed like any other accepted terminal so
    /// changing the payload at the consumed identity cannot make it executable.
    case stepLimitExceeded(requested: SimulationStepCount, maximum: SimulationStepCount)

    /// Raw and encoded image bytes retained by this terminal response.
    ///
    /// The Agent session budget intentionally excludes snapshots and Swift
    /// object or collection overhead. Saturating an impossible combined
    /// payload overflow at `Int.max` guarantees conservative admission.
    var retainedImageByteCount: Int {
        switch self {
        case let .capture(captureOutcome):
            switch captureOutcome {
            case let .completed(result):
                return result.artifact.encodedData.count

            case let .renderResultMismatch(_, renderResult),
                 let .cancelledAfterRender(_, renderResult),
                 let .artifactEncodingFailed(_, renderResult, _):
                return renderResult.image.bytes.count

            case let .artifactResultMismatch(_, renderResult, artifact):
                let result = renderResult.image.bytes.count.addingReportingOverflow(
                    artifact.encodedData.count
                )
                return result.overflow ? .max : result.partialValue

            case .coordinatorBusy,
                 .cancelledBeforeAdvance,
                 .advanceRejected,
                 .advanceResultMismatch,
                 .cancelledAfterAdvance,
                 .renderRejected,
                 .renderFailed,
                 .renderCancellationRequestIDMismatch,
                 .renderCancelledAfterSubmission:
                return 0
            }

        case let .currentCapture(captureOutcome):
            switch captureOutcome {
            case let .completed(result):
                return result.artifact.encodedData.count

            case let .renderResultMismatch(_, renderResult),
                 let .cancelledAfterRender(_, renderResult),
                 let .artifactEncodingFailed(_, renderResult, _):
                return renderResult.image.bytes.count

            case let .artifactResultMismatch(_, renderResult, artifact):
                let result = renderResult.image.bytes.count.addingReportingOverflow(
                    artifact.encodedData.count
                )
                return result.overflow ? .max : result.partialValue

            case .coordinatorBusy,
                 .cancelledBeforeRender,
                 .cursorMismatch,
                 .renderRejected,
                 .renderFailed,
                 .renderCancellationRequestIDMismatch,
                 .renderCancelledAfterSubmission:
                return 0
            }

        case .stepLimitExceeded:
            return 0
        }
    }
}
