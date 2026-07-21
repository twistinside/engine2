/// CPU-side preparation and submission facts for one render callback.
struct RenderFrameCPUDiagnostics: Codable, Equatable, Sendable {
    let frameSequence: RenderFrameSequence
    var sourceTick: SimulationTick?
    var didSourceTickChange: Bool
    var submittedInstanceCount: Int
    var renderPassCount: Int
    var drawCount: Int
    var submeshCount: Int
    var wasTruncated: Bool
    var result: RenderFrameCPUResult
    var durationNanoseconds: UInt64
}
