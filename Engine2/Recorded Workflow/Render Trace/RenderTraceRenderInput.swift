/// Validated domain input reconstructed from one ordered Render trace frame.
///
/// The value contains no file representation or backend resource. A Render
/// Runtime may project and encode it without constructing Simulation or Input.
nonisolated struct RenderTraceRenderInput: Equatable, Sendable {
    let sequence: UInt64
    let presentationSnapshot: SimulationPresentationSnapshot
    let viewpoint: RenderViewpoint
    let settings: OffscreenRenderSettings
    let clearColor: RenderTraceClearColor
}
