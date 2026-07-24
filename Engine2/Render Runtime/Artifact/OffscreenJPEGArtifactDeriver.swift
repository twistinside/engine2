/// Applies exact offscreen rendering, result correlation, and JPEG derivation.
///
/// This stateless connection accepts an immutable Simulation snapshot and
/// output-specific viewpoint by value. It never samples application state,
/// advances Simulation, or owns a cadence. Callers retain authority over source
/// selection and any single-flight policy that must span adjacent workflow
/// stages.
nonisolated struct OffscreenJPEGArtifactDeriver: Sendable {
    /// Injectable stateless encoding seam used by deterministic workflow tests.
    typealias JPEGEncode = @Sendable (
        OffscreenRenderResult,
        JPEGEncodingSettings
    ) async -> Result<RenderedImageArtifact, JPEGArtifactEncoderError>

    private let renderTarget: any POffscreenRenderTarget
    private let encodeJPEG: JPEGEncode

    /// Creates a production deriver around the concrete JPEG transformation.
    init(
        renderTarget: any POffscreenRenderTarget,
        jpegArtifactEncoder: JPEGArtifactEncoder = JPEGArtifactEncoder()
    ) {
        self.renderTarget = renderTarget
        self.encodeJPEG = { renderResult, settings in
            // JPEG derivation can be substantial at the offscreen size limit.
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
                    preconditionFailure(
                        "JPEGArtifactEncoder threw an undocumented error: \(error)"
                    )
                }
            }.value
        }
    }

    /// Creates a deriver with a deterministic typed encoding implementation.
    init(
        renderTarget: any POffscreenRenderTarget,
        encodeJPEG: @escaping JPEGEncode
    ) {
        self.renderTarget = renderTarget
        self.encodeJPEG = encodeJPEG
    }

    /// Renders and derives one artifact while enforcing complete provenance.
    func derive(
        sourceSnapshot: SimulationPresentationSnapshot,
        renderRequestID: OffscreenRenderRequestID,
        viewpoint: RenderViewpoint,
        renderSettings: OffscreenRenderSettings,
        jpegSettings: JPEGEncodingSettings
    ) async -> OffscreenJPEGArtifactOutcome {
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

        // Never encode a target response whose identity, source, policy, or
        // detached pixel extent diverges from the exact request.
        guard renderResult.requestID == renderRequest.id,
              renderResult.sourceCursor == sourceSnapshot.cursor,
              renderResult.viewpoint == renderRequest.viewpoint,
              renderResult.settings == renderRequest.settings,
              renderResult.image.size == renderRequest.settings.size else {
            return .renderResultMismatch(renderResult)
        }

        guard !Task.isCancelled else {
            return .cancelledAfterRender(renderResult)
        }

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
}
