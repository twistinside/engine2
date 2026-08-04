import Foundation

/// Complete measured distribution for one drained renderer-only workload.
///
/// Wall throughput includes frame-ring back pressure and the final GPU drain.
/// The phase distributions keep CPU projection/preparation, CPU command
/// recording/submission, and feedback-reported GPU execution distinct.
nonisolated struct RenderBenchmarkResult: Equatable, Sendable {
    let configuration: RenderBenchmarkConfiguration
    let pixelSize: RenderPixelSize
    let workloadFrameCount: Int
    let wallDuration: Duration
    let samples: [RenderBenchmarkSample]
    let projectionPreparation: RenderBenchmarkTimingStatistics
    let recordingSubmission: RenderBenchmarkTimingStatistics
    let gpuExecution: RenderBenchmarkTimingStatistics

    var wallMilliseconds: Double {
        wallDuration.milliseconds
    }

    var framesPerSecond: Double {
        Double(samples.count) * 1_000 / wallMilliseconds
    }

    init(
        configuration: RenderBenchmarkConfiguration,
        pixelSize: RenderPixelSize,
        workloadFrameCount: Int,
        wallDuration: Duration,
        samples: [RenderBenchmarkSample]
    ) {
        precondition(
            wallDuration > .zero,
            "A completed benchmark requires a positive measured wall duration."
        )
        precondition(
            !samples.isEmpty,
            "A completed benchmark requires at least one measured frame."
        )
        precondition(
            workloadFrameCount > 0,
            "A completed benchmark requires a nonempty source workload."
        )
        precondition(
            samples.count
                == workloadFrameCount * configuration.measuredIterationCount,
            "Measured samples must cover every source frame in every iteration."
        )

        self.configuration = configuration
        self.pixelSize = pixelSize
        self.workloadFrameCount = workloadFrameCount
        self.wallDuration = wallDuration
        self.samples = samples
        self.projectionPreparation = RenderBenchmarkTimingStatistics(
            durations: samples.map(\.projectionPreparationDuration)
        )
        self.recordingSubmission = RenderBenchmarkTimingStatistics(
            durations: samples.map(\.recordingSubmissionDuration)
        )
        self.gpuExecution = RenderBenchmarkTimingStatistics(
            durations: samples.map(\.gpuDuration)
        )
    }
}

extension RenderBenchmarkResult: CustomStringConvertible {
    var description: String {
        """
        Engine2 Render Benchmark
          workload: \(workloadFrameCount.formatted()) source frames; \
        \(configuration.warmupIterationCount.formatted()) warm-up iterations; \
        \(configuration.measuredIterationCount.formatted()) measured iterations
          measured submissions: \(samples.count.formatted())
          output: \(pixelSize.width)x\(pixelSize.height); no drawable, UI, Simulation Runtime, Input Runtime, or pixel readback
          wall: \(decimal(wallMilliseconds)) ms; \(decimal(framesPerSecond, digits: 2)) frames/s
          projection/preparation ms: \(distribution(projectionPreparation))
          recording/submission ms: \(distribution(recordingSubmission))
          GPU execution ms: \(distribution(gpuExecution))
        """
    }

    private func decimal(_ value: Double, digits: Int = 3) -> String {
        String(format: "%.\(digits)f", value)
    }

    private func distribution(
        _ statistics: RenderBenchmarkTimingStatistics
    ) -> String {
        """
        min \(decimal(statistics.minimumMilliseconds)); \
        median \(decimal(statistics.medianMilliseconds)); \
        mean \(decimal(statistics.meanMilliseconds)); \
        p95 \(decimal(statistics.p95Milliseconds)); \
        max \(decimal(statistics.maximumMilliseconds))
        """
    }
}
