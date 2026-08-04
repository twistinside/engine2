import Metal

/// One ordered, immutable renderer input selected before benchmark execution.
///
/// The value carries renderer-domain presentation state and output policy, but
/// no file representation or allocated GPU resource. File decoding and trace
/// version handling remain outside the benchmark, while the runner owns exact
/// projection and Metal resource resolution.
nonisolated struct RenderBenchmarkFrame: Sendable {
    let sequence: UInt64
    let presentationSnapshot: SimulationPresentationSnapshot
    let viewpoint: RenderViewpoint
    let settings: OffscreenRenderSettings
    let clearColor: MTLClearColor
}
