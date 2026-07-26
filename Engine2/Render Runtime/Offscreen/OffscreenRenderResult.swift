/// Completed detached artifact and exact attribution for one render request.
nonisolated struct OffscreenRenderResult: Equatable, Sendable {
    let requestID: OffscreenRenderRequestID
    let sourceCursor: SimulationCursor
    let viewpoint: RenderViewpoint
    let settings: OffscreenRenderSettings
    let image: RenderedBGRA8SRGBImage
}
