import Foundation

/// Distribution summary for one timing phase across all measured frames.
nonisolated struct RenderBenchmarkTimingStatistics: Equatable, Sendable {
    let totalMilliseconds: Double
    let minimumMilliseconds: Double
    let medianMilliseconds: Double
    let meanMilliseconds: Double
    let p95Milliseconds: Double
    let maximumMilliseconds: Double

    init(durations: [Duration]) {
        precondition(
            !durations.isEmpty,
            "Benchmark timing statistics require at least one sample."
        )
        precondition(
            durations.allSatisfy { $0 >= .zero },
            "Benchmark timing durations cannot be negative."
        )

        let sortedMilliseconds = durations.map(\.milliseconds).sorted()
        let totalMilliseconds = sortedMilliseconds.reduce(0, +)
        let medianIndex = sortedMilliseconds.count / 2
        let medianMilliseconds: Double
        if sortedMilliseconds.count.isMultiple(of: 2) {
            medianMilliseconds = (
                sortedMilliseconds[medianIndex - 1]
                + sortedMilliseconds[medianIndex]
            ) / 2
        } else {
            medianMilliseconds = sortedMilliseconds[medianIndex]
        }
        let p95Index = min(
            Int(ceil(Double(sortedMilliseconds.count) * 0.95)) - 1,
            sortedMilliseconds.count - 1
        )

        self.totalMilliseconds = totalMilliseconds
        self.minimumMilliseconds = sortedMilliseconds[0]
        self.medianMilliseconds = medianMilliseconds
        self.meanMilliseconds = totalMilliseconds
            / Double(sortedMilliseconds.count)
        self.p95Milliseconds = sortedMilliseconds[p95Index]
        self.maximumMilliseconds = sortedMilliseconds[
            sortedMilliseconds.count - 1
        ]
    }
}
