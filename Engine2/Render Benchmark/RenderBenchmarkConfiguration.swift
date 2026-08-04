/// Validated execution policy for one renderer-only benchmark run.
///
/// Every iteration renders all supplied frames once and in order. Warm-up
/// iterations complete and drain before the runner establishes its measured
/// wall-time interval.
nonisolated struct RenderBenchmarkConfiguration: Equatable, Sendable {
    static let defaultWarmupIterationCount = 1
    static let defaultMeasuredIterationCount = 5

    let warmupIterationCount: Int
    let measuredIterationCount: Int

    init(
        warmupIterationCount: Int = Self.defaultWarmupIterationCount,
        measuredIterationCount: Int = Self.defaultMeasuredIterationCount
    ) throws(RenderBenchmarkError) {
        guard warmupIterationCount >= 0 else {
            throw .invalidWarmupIterationCount(warmupIterationCount)
        }
        guard measuredIterationCount > 0 else {
            throw .invalidMeasuredIterationCount(measuredIterationCount)
        }

        self.warmupIterationCount = warmupIterationCount
        self.measuredIterationCount = measuredIterationCount
    }
}
