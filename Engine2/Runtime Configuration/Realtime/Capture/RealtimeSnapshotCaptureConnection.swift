/// Connects the live real-time presentation to a dedicated offscreen output.
///
/// This App-owned connection is not a Runtime. It samples one completed
/// Simulation publication and resolves the screen viewpoint against that same
/// snapshot in one Main Actor turn, then carries both immutable values through
/// exact offscreen rendering and JPEG derivation. It neither pauses nor advances
/// Simulation.
@MainActor
final class RealtimeSnapshotCaptureConnection: PRealtimeSnapshotCaptureTarget {
    private let presentationSource: any PSimulationPresentationSource
    private let viewpointSource: any PRenderViewpointSource
    private let imageDeriver: OffscreenJPEGArtifactDeriver
    private var isCapturing = false

    /// Creates a production connection around one dedicated Render Runtime.
    init(
        presentationSource: any PSimulationPresentationSource,
        viewpointSource: any PRenderViewpointSource,
        renderTarget: any POffscreenRenderTarget,
        jpegArtifactEncoder: JPEGArtifactEncoder = JPEGArtifactEncoder()
    ) {
        self.presentationSource = presentationSource
        self.viewpointSource = viewpointSource
        self.imageDeriver = OffscreenJPEGArtifactDeriver(
            renderTarget: renderTarget,
            jpegArtifactEncoder: jpegArtifactEncoder
        )
    }

    /// Creates a connection with a deterministic typed encoding implementation.
    init(
        presentationSource: any PSimulationPresentationSource,
        viewpointSource: any PRenderViewpointSource,
        renderTarget: any POffscreenRenderTarget,
        encodeJPEG: @escaping OffscreenJPEGArtifactDeriver.JPEGEncode
    ) {
        self.presentationSource = presentationSource
        self.viewpointSource = viewpointSource
        self.imageDeriver = OffscreenJPEGArtifactDeriver(
            renderTarget: renderTarget,
            encodeJPEG: encodeJPEG
        )
    }

    /// Selects one exact live value and derives its detached JPEG artifact.
    func capture(
        _ request: RealtimeSnapshotCaptureRequest
    ) async -> RealtimeSnapshotCaptureOutcome {
        guard !isCapturing else {
            return .connectionBusy
        }
        guard !Task.isCancelled else {
            return .cancelledBeforeRender
        }

        // These two synchronous reads form the selection boundary. Resolving
        // against this exact snapshot camera avoids mixing a later Simulation
        // publication with an earlier output override.
        let sourceSnapshot = presentationSource.latestPresentationSnapshot
        let viewpoint = viewpointSource.resolveViewpoint(
            defaultCamera: sourceSnapshot.camera
        )

        isCapturing = true
        defer {
            isCapturing = false
        }

        let derivation = await imageDeriver.derive(
            sourceSnapshot: sourceSnapshot,
            renderRequestID: request.renderRequestID,
            viewpoint: viewpoint,
            renderSettings: request.renderSettings,
            jpegSettings: request.jpegSettings
        )
        return outcome(
            from: derivation,
            sourceSnapshot: sourceSnapshot
        )
    }

    /// Adds the selected live publication to the shared derivation terminal.
    private func outcome(
        from derivation: OffscreenJPEGArtifactOutcome,
        sourceSnapshot: SimulationPresentationSnapshot
    ) -> RealtimeSnapshotCaptureOutcome {
        switch derivation {
        case let .completed(artifact):
            .completed(
                sourceSnapshot: sourceSnapshot,
                artifact: artifact
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
