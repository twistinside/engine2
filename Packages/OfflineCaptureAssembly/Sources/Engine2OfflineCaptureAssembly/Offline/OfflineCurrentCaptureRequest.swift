import Engine2
import Engine2AssemblySupport
/// Exact request to render and encode the coordinator's current presentation.
///
/// The mandatory expected cursor prevents a caller from accidentally observing
/// a newer completed Simulation state than intended. The coordinator supplies
/// the immutable presentation snapshot itself, so callers cannot inject an
/// arbitrary scene or gain access to the underlying Render Runtime.
public nonisolated struct OfflineCurrentCaptureRequest: Equatable, Sendable {
    public let expectedCursor: SimulationCursor
    public let renderRequestID: OffscreenRenderRequestID
    public let viewpoint: RenderViewpoint
    public let renderSettings: OffscreenRenderSettings
    public let encoding: ImageArtifactEncoding

    public init(
        expectedCursor: SimulationCursor,
        renderRequestID: OffscreenRenderRequestID,
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
