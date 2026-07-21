/// Mutable constant-space accumulator retained privately by `DiagnosticsRuntime`.
struct DiagnosticsAggregateAccumulator {
    private(set) var sampleCount = 0
    private(set) var durationSampleCount = 0
    private(set) var totalDurationNanoseconds: UInt64 = 0
    private(set) var minimumDurationNanoseconds: UInt64?
    private(set) var maximumDurationNanoseconds: UInt64?

    mutating func record(durationNanoseconds: UInt64?) {
        sampleCount += 1
        guard let durationNanoseconds else {
            return
        }

        durationSampleCount += 1
        let (newTotal, overflowed) = totalDurationNanoseconds
            .addingReportingOverflow(durationNanoseconds)
        totalDurationNanoseconds = overflowed ? .max : newTotal
        minimumDurationNanoseconds = min(
            minimumDurationNanoseconds ?? durationNanoseconds,
            durationNanoseconds
        )
        maximumDurationNanoseconds = max(
            maximumDurationNanoseconds ?? durationNanoseconds,
            durationNanoseconds
        )
    }

    func snapshot(for kind: DiagnosticsSampleKind) -> DiagnosticsSampleAggregate {
        DiagnosticsSampleAggregate(
            kind: kind,
            sampleCount: sampleCount,
            durationSampleCount: durationSampleCount,
            totalDurationNanoseconds: totalDurationNanoseconds,
            minimumDurationNanoseconds: minimumDurationNanoseconds,
            maximumDurationNanoseconds: maximumDurationNanoseconds
        )
    }
}
