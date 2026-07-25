/// Exact request to render and encode the coordinator's current presentation.
///
/// The mandatory expected cursor prevents a caller from accidentally observing
/// a newer completed Simulation state than intended. The coordinator supplies
/// the immutable presentation snapshot itself, so callers cannot inject an
/// arbitrary scene or gain access to the underlying Render Runtime.
nonisolated struct OfflineCurrentCaptureRequest: Equatable, Sendable {
    let expectedCursor: SimulationCursor
    let renderRequestID: OffscreenRenderRequestID
    let viewpoint: RenderViewpoint
    let renderSettings: OffscreenRenderSettings
    let encoding: ImageArtifactEncoding

    /// Creates one current-state render and artifact derivation request.
    init(
        expectedCursor: SimulationCursor,
        renderRequestID: OffscreenRenderRequestID = OffscreenRenderRequestID(),
        viewpoint: RenderViewpoint,
        renderSettings: OffscreenRenderSettings,
        encoding: ImageArtifactEncoding
    ) {
        self.expectedCursor = expectedCursor
        self.renderRequestID = renderRequestID
        self.viewpoint = viewpoint
        self.renderSettings = renderSettings
        self.encoding = encoding
    }
}
