/// Render-pass work encoded for one frame before queue commit.
struct FrameEncodeDiagnostics: Codable, Equatable, Sendable {
    let frameSequence: RenderFrameSequence
    let sourceTick: SimulationTick
    let renderPassCount: Int
    let drawCount: Int
    let submeshCount: Int
    let durationNanoseconds: UInt64
}
