/// Exact immutable input to one caller-driven offscreen render.
///
/// The request carries completed Simulation facts and an explicit output-owned
/// viewpoint by value. The render target therefore never samples live runtime
/// sources and can attribute its result to the precise inputs it consumed.
public nonisolated struct OffscreenRenderRequest: Equatable, Sendable {
    public let id: OffscreenRenderRequestID
    public let presentationSnapshot: SimulationPresentationSnapshot
    public let viewpoint: RenderViewpoint
    public let settings: OffscreenRenderSettings

    public init(
        id: OffscreenRenderRequestID,
        presentationSnapshot: SimulationPresentationSnapshot,
        viewpoint: RenderViewpoint,
        settings: OffscreenRenderSettings
    ) {
        self.id = id
        self.presentationSnapshot = presentationSnapshot
        self.viewpoint = viewpoint
        self.settings = settings
    }
}
