/// Sole effective advance authority in one offline capture assembly.
///
/// The coordinator serializes an exact Simulation request, an exact raw render
/// of the returned immutable snapshot, and awaited CPU-side JPEG derivation. It
/// keeps the CPU transform off its actor while retaining the single-flight gate.
/// It does not sample latest-value sources, expose its dependencies, retry
/// implicitly, or treat downstream failure as permission to advance again.
actor OfflineCaptureCoordinator: POfflineCaptureTarget {
    /// Injectable stateless encoding seam used by deterministic coordinator tests.
    typealias JPEGEncode = @Sendable (
        OffscreenRenderResult,
        JPEGEncodingSettings
    ) async -> Result<RenderedImageArtifact, JPEGArtifactEncoderError>

    private let advanceTarget: any PSimulationAdvanceTarget
    private let renderTarget: any POffscreenRenderTarget
    private let encodeJPEG: JPEGEncode

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
        self.renderTarget = renderTarget
        self.encodeJPEG = { renderResult, settings in
            // JPEG derivation can be substantial at the offscreen size limit.
            // Run the stateless Sendable transform outside this actor so its
            // explicit in-flight gate remains observable by overlapping calls.
            // The detached task deliberately does not inherit cancellation:
            // once encoding starts, its completed value wins and is reported.
            await Task.detached {
                do {
                    return .success(
                        try jpegArtifactEncoder.encode(
                            renderResult,
                            settings: settings
                        )
                    )
                } catch let failure as JPEGArtifactEncoderError {
                    return .failure(failure)
                } catch {
                    // `JPEGArtifactEncoder` owns a closed failure vocabulary.
                    // An undocumented error is a programming-contract
                    // violation, not a stringly typed capture state.
                    preconditionFailure(
                        "JPEGArtifactEncoder threw an undocumented error: \(error)"
                    )
                }
            }.value
        }
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
        encodeJPEG: @escaping JPEGEncode
    ) {
        self.advanceTarget = advanceTarget
        self.currentPresentationSnapshot = initialPresentationSnapshot
        self.renderTarget = renderTarget
        self.encodeJPEG = encodeJPEG
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
            from: await deriveImage(
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
            from: await deriveImage(
                sourceSnapshot: sourceSnapshot,
                renderRequestID: request.renderRequestID,
                viewpoint: request.viewpoint,
                renderSettings: request.renderSettings,
                jpegSettings: request.jpegSettings
            ),
            sourceSnapshot: sourceSnapshot
        )
    }

    /// Applies the common exact render, correlation, and JPEG policy.
    private func deriveImage(
        sourceSnapshot: SimulationPresentationSnapshot,
        renderRequestID: OffscreenRenderRequestID,
        viewpoint: RenderViewpoint,
        renderSettings: OffscreenRenderSettings,
        jpegSettings: JPEGEncodingSettings
    ) async -> OfflineImageDerivationOutcome {
        let renderRequest = OffscreenRenderRequest(
            id: renderRequestID,
            presentationSnapshot: sourceSnapshot,
            viewpoint: viewpoint,
            settings: renderSettings
        )
        let renderOutcome = await renderTarget.render(renderRequest)

        let renderResult: OffscreenRenderResult
        switch renderOutcome {
        case let .completed(result):
            renderResult = result

        case let .rejected(rejection):
            return .renderRejected(rejection)

        case let .failed(failure):
            return .renderFailed(failure)

        case let .cancelledAfterSubmission(requestID):
            guard requestID == renderRequest.id else {
                return .renderCancellationRequestIDMismatch(
                    expectedRequestID: renderRequest.id,
                    actualRequestID: requestID
                )
            }
            return .renderCancelledAfterSubmission(requestID)
        }

        // A completed target must echo every identity-bearing render input and
        // return pixels with the requested extent. Never encode an image whose
        // provenance diverges from the exact scene, viewpoint, settings, or
        // request that this coordinator issued.
        guard renderResult.requestID == renderRequest.id,
              renderResult.sourceCursor == sourceSnapshot.cursor,
              renderResult.viewpoint == renderRequest.viewpoint,
              renderResult.settings == renderRequest.settings,
              renderResult.image.size == renderRequest.settings.size else {
            return .renderResultMismatch(renderResult)
        }

        // The raw immutable value is retained in this outcome so the caller can
        // encode it later without repeating either authoritative predecessor.
        guard !Task.isCancelled else {
            return .cancelledAfterRender(renderResult)
        }

        // JPEG encoding is stateless and executes outside the coordinator actor
        // so actor-reentrant overlap observes the busy gate. The detached work
        // does not inherit cancellation: once this call begins, completion wins
        // because a successful artifact already exists and must not be hidden.
        switch await encodeJPEG(renderResult, jpegSettings) {
        case let .success(artifact):
            return .completed(artifact)

        case let .failure(failure):
            return .jpegEncodingFailed(
                renderResult: renderResult,
                failure: failure
            )
        }
    }

    /// Restores the existing advance-aware public outcome vocabulary.
    private func offlineCaptureOutcome(
        from outcome: OfflineImageDerivationOutcome,
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
        from outcome: OfflineImageDerivationOutcome,
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
