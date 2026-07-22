/// Exact immutable input to one caller-driven offscreen render.
///
/// The request carries completed Simulation facts and an explicit output-owned
/// viewpoint by value. The render target therefore never samples live runtime
/// sources and can attribute its result to the precise inputs it consumed.
nonisolated struct OffscreenRenderRequest: Equatable, Sendable {
    let id: OffscreenRenderRequestID
    let presentationSnapshot: SimulationPresentationSnapshot
    let viewpoint: RenderViewpoint
    let settings: OffscreenRenderSettings

    /// Creates a request with exact presentation and viewpoint inputs.
    init(
        id: OffscreenRenderRequestID = OffscreenRenderRequestID(),
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
