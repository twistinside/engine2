/// Eager Metal pipeline construction or cache reuse for one closed identity.
struct PipelineCompileDiagnostics: Codable, Equatable, Sendable {
    let pipelineID: MetalRenderPipelineID
    let wasCacheHit: Bool
    let succeeded: Bool
    let durationNanoseconds: UInt64
}
