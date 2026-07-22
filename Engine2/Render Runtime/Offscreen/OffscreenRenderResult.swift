/// Completed detached artifact and exact attribution for one render request.
nonisolated struct OffscreenRenderResult: Equatable, Sendable {
    let requestID: OffscreenRenderRequestID
    let sourceCursor: SimulationCursor
    let viewpoint: RenderViewpoint
    let settings: OffscreenRenderSettings
    let image: RenderedBGRA8SRGBImage

    /// Creates a completed result that echoes every identity-bearing input.
    init(
        requestID: OffscreenRenderRequestID,
        sourceCursor: SimulationCursor,
        viewpoint: RenderViewpoint,
        settings: OffscreenRenderSettings,
        image: RenderedBGRA8SRGBImage
    ) {
        self.requestID = requestID
        self.sourceCursor = sourceCursor
        self.viewpoint = viewpoint
        self.settings = settings
        self.image = image
    }
}
