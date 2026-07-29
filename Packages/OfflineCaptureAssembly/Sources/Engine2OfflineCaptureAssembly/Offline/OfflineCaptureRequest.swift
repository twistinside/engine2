import Engine2
import Engine2AssemblySupport
/// Immutable policy and exact Simulation command for one offline capture.
///
/// The coordinator executes ``advanceRequest`` at most once, renders only the
/// completed snapshot returned by that request, and applies the supplied image
/// encoding policy to that exact raw result. The render identity exists before work
/// begins so every downstream outcome remains correlated even when advancement
/// is rejected.
public nonisolated struct OfflineCaptureRequest: Sendable {
    public let advanceRequest: SimulationAdvanceRequest
    public let renderRequestID: OffscreenRenderRequestID
    public let viewpoint: RenderViewpoint
    public let renderSettings: OffscreenRenderSettings
    public let encoding: ImageArtifactEncoding

    public init(
        advanceRequest: SimulationAdvanceRequest,
        renderRequestID: OffscreenRenderRequestID,
        viewpoint: RenderViewpoint,
        renderSettings: OffscreenRenderSettings,
        encoding: ImageArtifactEncoding
    ) {
        self.advanceRequest = advanceRequest
        self.renderRequestID = renderRequestID
        self.viewpoint = viewpoint
        self.renderSettings = renderSettings
        self.encoding = encoding
    }
}
