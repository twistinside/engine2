import Testing
@testable import Engine2

struct RenderBenchmarkRunnerTests {
    @Test func runsProductionEncoderWithoutDrawableOrReadback() throws {
        let fixture = try RenderBenchmarkTestFixture()
        let frames = [
            fixture.frame(sequence: 10, tick: 0),
            fixture.frame(sequence: 20, tick: 1)
        ]
        let configuration = try RenderBenchmarkConfiguration(
            warmupIterationCount: 1,
            measuredIterationCount: 2
        )
        let runner = try RenderBenchmarkRunner(
            renderAssetCatalog: fixture.catalog,
            frames: frames,
            configuration: configuration
        )

        let result = try runner.run()

        #expect(result.workloadFrameCount == 2)
        #expect(result.samples.count == 4)
        #expect(result.samples.map(\.iteration) == [0, 0, 1, 1])
        #expect(result.samples.map(\.sequence) == [10, 20, 10, 20])
        #expect(
            result.samples.allSatisfy {
                $0.projectionPreparationDuration >= .zero
                    && $0.recordingSubmissionDuration >= .zero
                    && $0.gpuDuration >= .zero
            }
        )
        #expect(result.wallDuration > .zero)
        #expect(result.framesPerSecond > 0)
    }
}
