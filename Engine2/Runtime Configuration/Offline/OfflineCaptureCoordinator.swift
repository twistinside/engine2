/// Sole effective advance authority in one offline capture assembly.
///
/// The coordinator serializes an exact Simulation request, an exact raw render
/// of the returned immutable snapshot, and awaited CPU-side JPEG derivation. It
/// keeps the CPU transform off its actor while retaining the single-flight gate.
/// It does not sample latest-value sources, expose its dependencies, retry
/// implicitly, or treat downstream failure as permission to advance again.
actor OfflineCaptureCoordinator: POfflineCaptureTarget {
    private let advanceTarget: any PSimulationAdvanceTarget
    private let imageDeriver: OffscreenJPEGArtifactDeriver

    /// Sole exact presentation retained for current-cursor output work.
    ///
    /// The value begins at the Simulation Runtime's initial cursor and changes
    /// only when this coordinator receives a completed exact advance result.
    /// Retaining one value supports repeated outputs without creating history.
    private var currentPresentationSnapshot: SimulationPresentationSnapshot

    /// True while one request owns every stage of the serial workflow.
    ///
    /// Actor reentrancy permits another caller to enter while a dependency is
    /// awaited. This explicit gate turns that overlap into immediate typed
    /// backpressure instead of an invisible actor mailbox queue.
    private var isCapturing = false

    /// Creates the production coordinator around the concrete JPEG derivation.
    init(
        advanceTarget: any PSimulationAdvanceTarget,
        initialPresentationSnapshot: SimulationPresentationSnapshot,
        renderTarget: any POffscreenRenderTarget,
        jpegArtifactEncoder: JPEGArtifactEncoder = JPEGArtifactEncoder()
    ) {
        self.advanceTarget = advanceTarget
        self.currentPresentationSnapshot = initialPresentationSnapshot
        self.imageDeriver = OffscreenJPEGArtifactDeriver(
            renderTarget: renderTarget,
            jpegArtifactEncoder: jpegArtifactEncoder
        )
    }

    /// Creates a coordinator with a deterministic typed encoding implementation.
    ///
    /// Production composition uses the concrete-encoder initializer above. This
    /// seam makes rare Image I/O failures testable without adding an encoder
    /// Runtime, mutable test hooks, or malformed image values to production.
    init(
        advanceTarget: any PSimulationAdvanceTarget,
        initialPresentationSnapshot: SimulationPresentationSnapshot,
        renderTarget: any POffscreenRenderTarget,
        encodeJPEG: @escaping @Sendable (
            OffscreenRenderResult,
            JPEGEncodingSettings
        ) async -> Result<RenderedImageArtifact, JPEGArtifactEncoderError>
    ) {
        self.advanceTarget = advanceTarget
        self.currentPresentationSnapshot = initialPresentationSnapshot
        self.imageDeriver = OffscreenJPEGArtifactDeriver(
            renderTarget: renderTarget,
            encodeJPEG: encodeJPEG
        )
    }

    /// Advances exactly once, then renders and encodes that completed result.
    func capture(_ request: OfflineCaptureRequest) async -> OfflineCaptureOutcome {
        // Busy takes precedence because another workflow already owns the only
        // effective authority, regardless of this caller's cancellation state.
        guard !isCapturing else {
            return .coordinatorBusy
        }
        guard !Task.isCancelled else {
            return .cancelledBeforeAdvance
        }

        isCapturing = true
        defer {
            isCapturing = false
        }

        let coordinatorCursorBeforeAdvance =
            currentPresentationSnapshot.cursor
        let advanceOutcome = await advanceTarget.advance(request.advanceRequest)
        let advanceResult: SimulationAdvanceResult
        switch advanceOutcome {
        case let .completed(result):
            advanceResult = result

            // Advancement is authoritative even if cancellation or an output
            // stage fails afterward. Publish its completed immutable value to
            // this coordinator's one-slot current-state cache immediately.
            currentPresentationSnapshot = result.finalPresentationSnapshot

            // A completed value is internally coherent by construction, but a
            // conforming target must also correlate it with the coordinator's
            // retained cursor and the exact command that was submitted. Work
            // may already be committed, so retain the returned final snapshot
            // while refusing to render a range that was not the requested one.
            guard result.initialCursor == coordinatorCursorBeforeAdvance,
                  request.advanceRequest.expectedCursor == nil
                    || request.advanceRequest.expectedCursor
                        == result.initialCursor,
                  result.completedStepCount.rawValue
                    == request.advanceRequest.stepCount.rawValue else {
                return .advanceResultMismatch(
                    coordinatorCursor: coordinatorCursorBeforeAdvance,
                    requestedExpectedCursor:
                        request.advanceRequest.expectedCursor,
                    requestedStepCount: request.advanceRequest.stepCount,
                    result: result
                )
            }

        case let .rejected(rejection):
            return .advanceRejected(rejection)
        }

        // Simulation ignores cancellation once exact work has begun. Preserve
        // its returned committed result and stop only at this stage boundary.
        guard !Task.isCancelled else {
            return .cancelledAfterAdvance(advanceResult)
        }

        return offlineCaptureOutcome(
            from: await imageDeriver.derive(
                sourceSnapshot: advanceResult.finalPresentationSnapshot,
                renderRequestID: request.renderRequestID,
                viewpoint: request.viewpoint,
                renderSettings: request.renderSettings,
                jpegSettings: request.jpegSettings
            ),
            advanceResult: advanceResult
        )
    }

    /// Renders and encodes the retained exact presentation without advancing.
    func captureCurrent(
        _ request: OfflineCurrentCaptureRequest
    ) async -> OfflineCurrentCaptureOutcome {
        // One gate spans both operation kinds. A current render cannot slip
        // between an accepted advance and its output, and an advance cannot
        // replace the selected snapshot while current output work is awaited.
        guard !isCapturing else {
            return .coordinatorBusy
        }
        guard !Task.isCancelled else {
            return .cancelledBeforeRender
        }

        let sourceSnapshot = currentPresentationSnapshot
        guard request.expectedCursor == sourceSnapshot.cursor else {
            return .cursorMismatch(
                expected: request.expectedCursor,
                current: sourceSnapshot.cursor
            )
        }

        isCapturing = true
        defer {
            isCapturing = false
        }

        return offlineCurrentCaptureOutcome(
            from: await imageDeriver.derive(
                sourceSnapshot: sourceSnapshot,
                renderRequestID: request.renderRequestID,
                viewpoint: request.viewpoint,
                renderSettings: request.renderSettings,
                jpegSettings: request.jpegSettings
            ),
            sourceSnapshot: sourceSnapshot
        )
    }

    /// Restores the existing advance-aware public outcome vocabulary.
    private func offlineCaptureOutcome(
        from outcome: OffscreenJPEGArtifactOutcome,
        advanceResult: SimulationAdvanceResult
    ) -> OfflineCaptureOutcome {
        switch outcome {
        case let .completed(artifact):
            .completed(
                OfflineCaptureResult(
                    advanceResult: advanceResult,
                    artifact: artifact
                )
            )

        case let .renderRejected(rejection):
            .renderRejected(
                advanceResult: advanceResult,
                rejection: rejection
            )

        case let .renderFailed(failure):
            .renderFailed(
                advanceResult: advanceResult,
                failure: failure
            )

        case let .renderCancellationRequestIDMismatch(expected, actual):
            .renderCancellationRequestIDMismatch(
                advanceResult: advanceResult,
                expectedRequestID: expected,
                actualRequestID: actual
            )

        case let .renderCancelledAfterSubmission(requestID):
            .renderCancelledAfterSubmission(
                advanceResult: advanceResult,
                requestID: requestID
            )

        case let .renderResultMismatch(renderResult):
            .renderResultMismatch(
                advanceResult: advanceResult,
                renderResult: renderResult
            )

        case let .cancelledAfterRender(renderResult):
            .cancelledAfterRender(
                advanceResult: advanceResult,
                renderResult: renderResult
            )

        case let .jpegEncodingFailed(renderResult, failure):
            .jpegEncodingFailed(
                advanceResult: advanceResult,
                renderResult: renderResult,
                failure: failure
            )
        }
    }

    /// Adds current-presentation provenance to the common output terminal.
    private func offlineCurrentCaptureOutcome(
        from outcome: OffscreenJPEGArtifactOutcome,
        sourceSnapshot: SimulationPresentationSnapshot
    ) -> OfflineCurrentCaptureOutcome {
        switch outcome {
        case let .completed(artifact):
            .completed(
                OfflineCurrentCaptureResult(
                    sourceSnapshot: sourceSnapshot,
                    artifact: artifact
                )
            )

        case let .renderRejected(rejection):
            .renderRejected(
                sourceSnapshot: sourceSnapshot,
                rejection: rejection
            )

        case let .renderFailed(failure):
            .renderFailed(
                sourceSnapshot: sourceSnapshot,
                failure: failure
            )

        case let .renderCancellationRequestIDMismatch(expected, actual):
            .renderCancellationRequestIDMismatch(
                sourceSnapshot: sourceSnapshot,
                expectedRequestID: expected,
                actualRequestID: actual
            )

        case let .renderCancelledAfterSubmission(requestID):
            .renderCancelledAfterSubmission(
                sourceSnapshot: sourceSnapshot,
                requestID: requestID
            )

        case let .renderResultMismatch(renderResult):
            .renderResultMismatch(
                sourceSnapshot: sourceSnapshot,
                renderResult: renderResult
            )

        case let .cancelledAfterRender(renderResult):
            .cancelledAfterRender(
                sourceSnapshot: sourceSnapshot,
                renderResult: renderResult
            )

        case let .jpegEncodingFailed(renderResult, failure):
            .jpegEncodingFailed(
                sourceSnapshot: sourceSnapshot,
                renderResult: renderResult,
                failure: failure
            )
        }
    }
}
