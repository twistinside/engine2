/// Sole effective advance authority in one offline capture assembly.
///
/// The coordinator serializes an exact Simulation request, an exact raw render
/// of the returned immutable snapshot, and awaited CPU-side artifact derivation.
/// It retains the single-flight gate while the encoder owns its execution
/// context. The coordinator does not sample latest-value sources, expose its
/// dependencies, retry implicitly, or treat downstream failure as permission
/// to advance again.
actor OfflineCaptureCoordinator: POfflineCaptureTarget {
    private let advanceTarget: any PSimulationAdvanceTarget
    private let imageDeriver: OffscreenImageArtifactDeriver

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

    /// Creates a coordinator from independently owned workflow capabilities.
    init(
        advanceTarget: any PSimulationAdvanceTarget,
        initialPresentationSnapshot: SimulationPresentationSnapshot,
        renderTarget: any POffscreenRenderTarget,
        artifactEncoder: any PImageArtifactEncoder
    ) {
        self.advanceTarget = advanceTarget
        self.currentPresentationSnapshot = initialPresentationSnapshot
        self.imageDeriver = OffscreenImageArtifactDeriver(
            renderTarget: renderTarget,
            artifactEncoder: artifactEncoder
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

        return OfflineCaptureOutcome(
            artifactOutcome: await imageDeriver.derive(
                sourceSnapshot: advanceResult.finalPresentationSnapshot,
                renderRequestID: request.renderRequestID,
                viewpoint: request.viewpoint,
                renderSettings: request.renderSettings,
                encoding: request.encoding
            ),
            advanceResult: advanceResult
        )
    }

    /// Renders and encodes the retained exact presentation without advancing.
    func captureCurrent(_ request: OfflineCurrentCaptureRequest) async -> OfflineCurrentCaptureOutcome {
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

        return OfflineCurrentCaptureOutcome(
            artifactOutcome: await imageDeriver.derive(
                sourceSnapshot: sourceSnapshot,
                renderRequestID: request.renderRequestID,
                viewpoint: request.viewpoint,
                renderSettings: request.renderSettings,
                encoding: request.encoding
            ),
            sourceSnapshot: sourceSnapshot
        )
    }
}
