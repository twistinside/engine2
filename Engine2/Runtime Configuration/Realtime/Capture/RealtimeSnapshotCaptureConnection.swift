/// Connects the live real-time presentation to a dedicated offscreen output.
///
/// This App-owned connection is not a Runtime. It samples one completed
/// Simulation publication and locks the exact render viewpoint to that
/// publication's camera, then carries both immutable values through exact
/// offscreen rendering and artifact derivation. It neither pauses nor advances
/// Simulation, and it owns no independently mutable camera state.
final class RealtimeSnapshotCaptureConnection: PRealtimeSnapshotCaptureTarget {
    private let presentationSource: any PSimulationPresentationSource
    private let viewpointID: RenderViewpointID
    private let imageDeriver: OffscreenImageArtifactDeriver
    private var isCapturing = false

    /// Creates a production connection around one dedicated Render Runtime.
    init(
        presentationSource: any PSimulationPresentationSource,
        renderTarget: any POffscreenRenderTarget,
        viewpointID: RenderViewpointID = RenderViewpointID(),
        artifactEncoder: any PImageArtifactEncoder = ImageIOArtifactEncoder()
    ) {
        self.presentationSource = presentationSource
        self.viewpointID = viewpointID
        self.imageDeriver = OffscreenImageArtifactDeriver(
            renderTarget: renderTarget,
            artifactEncoder: artifactEncoder
        )
    }

    /// Selects one exact live value and derives its detached image artifact.
    func capture(_ request: RealtimeSnapshotCaptureRequest) async -> RealtimeSnapshotCaptureOutcome {
        guard !isCapturing else {
            return .connectionBusy
        }
        guard !Task.isCancelled else {
            return .cancelledBeforeRender
        }

        // The selected snapshot is the sole camera authority. Revision zero is
        // stable because this connection owns no output-specific camera state;
        // camera changes are attributed by the selected Simulation cursor.
        let sourceSnapshot = presentationSource.latestPresentationSnapshot
        let viewpoint = RenderViewpoint(
            id: viewpointID,
            revision: .zero,
            camera: sourceSnapshot.camera
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
            encoding: request.encoding
        )
        return outcome(
            from: derivation,
            sourceSnapshot: sourceSnapshot
        )
    }

    /// Adds the selected live publication to the shared derivation terminal.
    private func outcome(
        from derivation: OffscreenImageArtifactOutcome,
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

        case let .artifactEncodingFailed(renderResult, failure):
            .artifactEncodingFailed(
                sourceSnapshot: sourceSnapshot,
                renderResult: renderResult,
                failure: failure
            )

        case let .artifactResultMismatch(renderResult, artifact):
            .artifactResultMismatch(
                sourceSnapshot: sourceSnapshot,
                renderResult: renderResult,
                artifact: artifact
            )
        }
    }
}
