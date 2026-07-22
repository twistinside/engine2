/// Queue feedback correlated to CPU frame, Simulation tick, and frame slot.
struct GPUFrameDiagnostics: Codable, Equatable, Sendable {
    let submissionID: RenderSubmissionID
    let frameSequence: RenderFrameSequence
    let sourceTick: SimulationTick
    let frameSlot: Int
    let result: GPUFrameResult

    /// Framework feedback errors are an open vocabulary outside Engine2.
    let errorType: String?

    let durationNanoseconds: UInt64
}
