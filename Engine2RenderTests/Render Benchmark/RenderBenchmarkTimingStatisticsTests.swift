import Testing
@testable import Engine2

struct RenderBenchmarkTimingStatisticsTests {
    @Test func summarizesEvenDistributionAndNearestRankP95() {
        let statistics = RenderBenchmarkTimingStatistics(
            durations: [
                .milliseconds(4),
                .milliseconds(1),
                .milliseconds(3),
                .milliseconds(2)
            ]
        )

        #expect(statistics.totalMilliseconds == 10)
        #expect(statistics.minimumMilliseconds == 1)
        #expect(statistics.medianMilliseconds == 2.5)
        #expect(statistics.meanMilliseconds == 2.5)
        #expect(statistics.p95Milliseconds == 4)
        #expect(statistics.maximumMilliseconds == 4)
    }

    @Test func resultSeparatesPhasesAndComputesWallThroughput() throws {
        let configuration = try RenderBenchmarkConfiguration(
            warmupIterationCount: 0,
            measuredIterationCount: 2
        )
        let samples = [
            RenderBenchmarkSample(
                iteration: 0,
                sequence: 9,
                projectionPreparationDuration: .milliseconds(1),
                recordingSubmissionDuration: .milliseconds(2),
                gpuDuration: .milliseconds(3)
            ),
            RenderBenchmarkSample(
                iteration: 1,
                sequence: 9,
                projectionPreparationDuration: .milliseconds(2),
                recordingSubmissionDuration: .milliseconds(4),
                gpuDuration: .milliseconds(6)
            )
        ]

        let result = RenderBenchmarkResult(
            configuration: configuration,
            pixelSize: try RenderPixelSize(width: 16, height: 16),
            workloadFrameCount: 1,
            wallDuration: .milliseconds(20),
            samples: samples
        )

        #expect(result.samples == samples)
        #expect(result.projectionPreparation.meanMilliseconds == 1.5)
        #expect(result.recordingSubmission.meanMilliseconds == 3)
        #expect(result.gpuExecution.meanMilliseconds == 4.5)
        #expect(result.framesPerSecond == 100)
    }
}
