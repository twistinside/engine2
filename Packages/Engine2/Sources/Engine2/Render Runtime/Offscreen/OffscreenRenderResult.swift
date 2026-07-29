/// Completed detached artifact and exact attribution for one render request.
public nonisolated struct OffscreenRenderResult: Equatable, Sendable {
    public let requestID: OffscreenRenderRequestID
    public let sourceCursor: SimulationCursor
    public let viewpoint: RenderViewpoint
    public let settings: OffscreenRenderSettings
    public let image: RenderedBGRA8SRGBImage

    public init(
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
