/// Applies exact offscreen rendering, correlation, and artifact derivation.
///
/// This stateless connection accepts an immutable Simulation snapshot and
/// output-specific viewpoint by value. It never samples application state,
/// advances Simulation, or owns a cadence. Callers retain authority over source
/// selection and any single-flight policy that must span adjacent workflow
/// stages.
nonisolated struct OffscreenImageArtifactDeriver: Sendable {
    private let artifactEncoder: any PImageArtifactEncoder
    private let renderTarget: any POffscreenRenderTarget

    /// Creates a deriver from independently owned Render and encoding capabilities.
    ///
    /// Initialization only wires dependencies. Rendering, CPU scheduling, and
    /// all fallible work begin in ``derive(sourceSnapshot:renderRequestID:viewpoint:renderSettings:encoding:)``.
    init(renderTarget: any POffscreenRenderTarget, artifactEncoder: any PImageArtifactEncoder) {
        self.renderTarget = renderTarget
        self.artifactEncoder = artifactEncoder
    }

    /// Renders and derives one artifact while enforcing complete provenance.
    func derive(
        sourceSnapshot: SimulationPresentationSnapshot,
        renderRequestID: OffscreenRenderRequestID,
        viewpoint: RenderViewpoint,
        renderSettings: OffscreenRenderSettings,
        encoding: ImageArtifactEncoding
    ) async -> OffscreenImageArtifactOutcome {
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

        do {
            let artifact = try await artifactEncoder.encode(
                renderResult,
                as: encoding
            )
            guard !artifact.encodedData.isEmpty,
                  artifact.sourceRequestID == renderResult.requestID,
                  artifact.sourceCursor == renderResult.sourceCursor,
                  artifact.viewpoint == renderResult.viewpoint,
                  artifact.renderSettings == renderResult.settings,
                  artifact.encoding == encoding else {
                return .artifactResultMismatch(
                    renderResult: renderResult,
                    artifact: artifact
                )
            }
            return .completed(artifact)
        } catch {
            return .artifactEncodingFailed(
                renderResult: renderResult,
                failure: error
            )
        }
    }
}
