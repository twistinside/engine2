/// Render-owned outcome of projecting one immutable presentation snapshot.
struct RenderProjectionDiagnostics: Codable, Equatable, Sendable {
    let sourceTick: SimulationTick
    let publishedPresentationCount: Int
    let acceptedInstanceCount: Int
    let rejectedPresentationCount: Int
    let durationNanoseconds: UInt64
}
