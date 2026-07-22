import Testing
@testable import Engine2

struct DiagnosticsAggregateAccumulatorTests {
    @Test func payloadsWithoutDurationStillCountAsSamples() {
        var accumulator = DiagnosticsAggregateAccumulator()
        accumulator.record(durationNanoseconds: nil)
        accumulator.record(durationNanoseconds: nil)

        let snapshot = accumulator.snapshot(for: .inputReceive)
        #expect(snapshot.sampleCount == 2)
        #expect(snapshot.durationSampleCount == 0)
        #expect(snapshot.totalDurationNanoseconds == 0)
        #expect(snapshot.minimumDurationNanoseconds == nil)
        #expect(snapshot.maximumDurationNanoseconds == nil)
    }

    @Test func zeroIsARealDurationAndParticipatesInBounds() {
        var accumulator = DiagnosticsAggregateAccumulator()
        accumulator.record(durationNanoseconds: 8)
        accumulator.record(durationNanoseconds: 0)
        accumulator.record(durationNanoseconds: 5)

        let snapshot = accumulator.snapshot(for: .simulationStep)
        #expect(snapshot.durationSampleCount == 3)
        #expect(snapshot.totalDurationNanoseconds == 13)
        #expect(snapshot.minimumDurationNanoseconds == 0)
        #expect(snapshot.maximumDurationNanoseconds == 8)
    }

    @Test func overflowingDurationTotalSaturatesInsteadOfWrapping() {
        var accumulator = DiagnosticsAggregateAccumulator()
        accumulator.record(durationNanoseconds: .max)
        accumulator.record(durationNanoseconds: 1)
        accumulator.record(durationNanoseconds: 99)

        let snapshot = accumulator.snapshot(for: .gpuFrame)
        #expect(snapshot.totalDurationNanoseconds == .max)
        #expect(snapshot.minimumDurationNanoseconds == 1)
        #expect(snapshot.maximumDurationNanoseconds == .max)
    }

    @Test func priorSnapshotsRemainDetachedFromLaterRecords() {
        var accumulator = DiagnosticsAggregateAccumulator()
        accumulator.record(durationNanoseconds: 3)
        let before = accumulator.snapshot(for: .frameEncode)

        accumulator.record(durationNanoseconds: 7)
        let after = accumulator.snapshot(for: .frameEncode)

        #expect(before.sampleCount == 1)
        #expect(before.totalDurationNanoseconds == 3)
        #expect(after.sampleCount == 2)
        #expect(after.totalDurationNanoseconds == 10)
    }
}
