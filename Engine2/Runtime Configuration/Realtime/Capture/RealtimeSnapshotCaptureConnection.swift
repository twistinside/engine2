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

    /// Creates a connection from fully injected output identity and encoding
    /// dependencies for restoration or deterministic tests.
    init(
        presentationSource: any PSimulationPresentationSource,
        renderTarget: any POffscreenRenderTarget,
        viewpointID: RenderViewpointID,
        artifactEncoder: any PImageArtifactEncoder
    ) {
        self.presentationSource = presentationSource
        self.viewpointID = viewpointID
        self.imageDeriver = OffscreenImageArtifactDeriver(
            renderTarget: renderTarget,
            artifactEncoder: artifactEncoder
        )
    }

    /// Creates a production connection that owns a fresh stable viewpoint
    /// identity and the production image encoder.
    convenience init(
        presentationSource: any PSimulationPresentationSource,
        renderTarget: any POffscreenRenderTarget
    ) {
        self.init(
            presentationSource: presentationSource,
            renderTarget: renderTarget,
            viewpointID: RenderViewpointID(),
            artifactEncoder: ImageIOArtifactEncoder()
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

        return RealtimeSnapshotCaptureOutcome(
            artifactOutcome: await imageDeriver.derive(
                sourceSnapshot: sourceSnapshot,
                renderRequestID: request.renderRequestID,
                viewpoint: viewpoint,
                renderSettings: request.renderSettings,
                encoding: request.encoding
            ),
            sourceSnapshot: sourceSnapshot
        )
    }
}
