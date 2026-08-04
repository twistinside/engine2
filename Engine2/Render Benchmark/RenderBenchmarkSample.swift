/// Timing attribution for one measured renderer submission.
///
/// Slot back pressure is represented by the run's wall throughput rather than
/// charged to either CPU phase. GPU duration comes from Metal queue feedback,
/// not from a CPU wait around submission.
nonisolated struct RenderBenchmarkSample: Equatable, Sendable {
    let iteration: Int
    let sequence: UInt64
    let projectionPreparationDuration: Duration
    let recordingSubmissionDuration: Duration
    let gpuDuration: Duration
}
