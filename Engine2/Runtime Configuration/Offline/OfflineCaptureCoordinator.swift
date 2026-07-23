/// Sole effective advance authority in one offline capture assembly.
///
/// The coordinator serializes an exact Simulation request, an exact raw render
/// of the returned immutable snapshot, and synchronous JPEG derivation. It does
/// not sample latest-value sources, expose its dependencies, retry implicitly,
/// or reinterpret a downstream failure as permission to advance again.
actor OfflineCaptureCoordinator: POfflineCaptureTarget {
    /// Injectable stateless encoding seam used by deterministic coordinator tests.
    typealias JPEGEncode = @Sendable (
        OffscreenRenderResult,
        JPEGEncodingSettings
    ) -> Result<RenderedImageArtifact, JPEGArtifactEncoderError>

    private let advanceTarget: any PSimulationAdvanceTarget
    private let renderTarget: any POffscreenRenderTarget
    private let encodeJPEG: JPEGEncode

    /// True while one request owns every stage of the serial workflow.
    ///
    /// Actor reentrancy permits another caller to enter while a dependency is
    /// awaited. This explicit gate turns that overlap into immediate typed
    /// backpressure instead of an invisible actor mailbox queue.
    private var isCapturing = false

    /// Creates the production coordinator around the concrete JPEG derivation.
    init(
        advanceTarget: any PSimulationAdvanceTarget,
        renderTarget: any POffscreenRenderTarget,
        jpegArtifactEncoder: JPEGArtifactEncoder = JPEGArtifactEncoder()
    ) {
        self.advanceTarget = advanceTarget
        self.renderTarget = renderTarget
        self.encodeJPEG = { renderResult, settings in
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
                // `JPEGArtifactEncoder` owns a closed failure vocabulary. An
                // undocumented error is a programming-contract violation, not
                // a new recoverable capture state that should be stringly typed.
                preconditionFailure(
                    "JPEGArtifactEncoder threw an undocumented error: \(error)"
                )
            }
        }
    }

    /// Creates a coordinator with a deterministic typed encoding implementation.
    ///
    /// Production composition uses the concrete-encoder initializer above. This
    /// seam makes rare Image I/O failures testable without adding an encoder
    /// Runtime, mutable test hooks, or malformed image values to production.
    init(
        advanceTarget: any PSimulationAdvanceTarget,
        renderTarget: any POffscreenRenderTarget,
        encodeJPEG: @escaping JPEGEncode
    ) {
        self.advanceTarget = advanceTarget
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

        let advanceOutcome = await advanceTarget.advance(request.advanceRequest)
        let advanceResult: SimulationAdvanceResult
        switch advanceOutcome {
        case let .completed(result):
            advanceResult = result

        case let .rejected(rejection):
            return .advanceRejected(rejection)
        }

        // Simulation ignores cancellation once exact work has begun. Preserve
        // its returned committed result and stop only at this stage boundary.
        guard !Task.isCancelled else {
            return .cancelledAfterAdvance(advanceResult)
        }

        let renderRequest = OffscreenRenderRequest(
            id: request.renderRequestID,
            presentationSnapshot: advanceResult.finalPresentationSnapshot,
            viewpoint: request.viewpoint,
            settings: request.renderSettings
        )
        let renderOutcome = await renderTarget.render(renderRequest)

        let renderResult: OffscreenRenderResult
        switch renderOutcome {
        case let .completed(result):
            renderResult = result

        case let .rejected(rejection):
            return .renderRejected(
                advanceResult: advanceResult,
                rejection: rejection
            )

        case let .failed(failure):
            return .renderFailed(
                advanceResult: advanceResult,
                failure: failure
            )

        case let .cancelledAfterSubmission(requestID):
            return .renderCancelledAfterSubmission(
                advanceResult: advanceResult,
                requestID: requestID
            )
        }

        // A completed target must echo every identity-bearing render input.
        // Never encode an image whose provenance diverges from the exact scene,
        // viewpoint, settings, or request that this coordinator issued.
        guard renderResult.requestID == renderRequest.id,
              renderResult.sourceCursor == advanceResult.finalCursor,
              renderResult.viewpoint == renderRequest.viewpoint,
              renderResult.settings == renderRequest.settings else {
            return .renderResultMismatch(
                advanceResult: advanceResult,
                renderResult: renderResult
            )
        }

        // The raw immutable value is retained in this outcome so the caller can
        // encode it later without repeating either authoritative predecessor.
        guard !Task.isCancelled else {
            return .cancelledAfterRender(
                advanceResult: advanceResult,
                renderResult: renderResult
            )
        }

        // JPEG encoding is synchronous and stateless. Once this call begins,
        // completion wins over cancellation because there is no safe internal
        // cancellation boundary and a successful artifact already exists.
        switch encodeJPEG(renderResult, request.jpegSettings) {
        case let .success(artifact):
            return .completed(
                OfflineCaptureResult(
                    advanceResult: advanceResult,
                    artifact: artifact
                )
            )

        case let .failure(failure):
            return .jpegEncodingFailed(
                advanceResult: advanceResult,
                renderResult: renderResult,
                failure: failure
            )
        }
    }
}
