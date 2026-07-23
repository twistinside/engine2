/// Immutable policy and exact Simulation command for one offline capture.
///
/// The coordinator executes ``advanceRequest`` at most once, renders only the
/// completed snapshot returned by that request, and applies the supplied JPEG
/// policy to that exact raw result. The render identity exists before work
/// begins so every downstream outcome remains correlated even when advancement
/// is rejected.
nonisolated struct OfflineCaptureRequest: Sendable {
    let advanceRequest: SimulationAdvanceRequest
    let renderRequestID: OffscreenRenderRequestID
    let viewpoint: RenderViewpoint
    let renderSettings: OffscreenRenderSettings
    let jpegSettings: JPEGEncodingSettings

    /// Creates one bounded serial capture workflow.
    init(
        advanceRequest: SimulationAdvanceRequest,
        renderRequestID: OffscreenRenderRequestID = OffscreenRenderRequestID(),
        viewpoint: RenderViewpoint,
        renderSettings: OffscreenRenderSettings,
        jpegSettings: JPEGEncodingSettings = JPEGEncodingSettings()
    ) {
        self.advanceRequest = advanceRequest
        self.renderRequestID = renderRequestID
        self.viewpoint = viewpoint
        self.renderSettings = renderSettings
        self.jpegSettings = jpegSettings
    }
}
