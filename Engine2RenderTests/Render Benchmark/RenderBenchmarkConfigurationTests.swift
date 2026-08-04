import Testing
@testable import Engine2

struct RenderBenchmarkConfigurationTests {
    @Test func defaultsSelectOneWarmupAndFiveMeasuredIterations() throws {
        let configuration = try RenderBenchmarkConfiguration()

        #expect(configuration.warmupIterationCount == 1)
        #expect(configuration.measuredIterationCount == 5)
    }

    @Test func validationAcceptsNoWarmupAndRequiresMeasuredWork() throws {
        let configuration = try RenderBenchmarkConfiguration(
            warmupIterationCount: 0,
            measuredIterationCount: 1
        )
        #expect(configuration.warmupIterationCount == 0)
        #expect(configuration.measuredIterationCount == 1)

        #expect(
            throws: RenderBenchmarkError.invalidWarmupIterationCount(-1)
        ) {
            try RenderBenchmarkConfiguration(
                warmupIterationCount: -1,
                measuredIterationCount: 1
            )
        }
        #expect(
            throws: RenderBenchmarkError.invalidMeasuredIterationCount(0)
        ) {
            try RenderBenchmarkConfiguration(
                warmupIterationCount: 0,
                measuredIterationCount: 0
            )
        }
    }
}
