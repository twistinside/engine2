import Foundation

/// File and iteration policy selected for one renderer-only benchmark process.
struct RenderBenchmarkCommandConfiguration {
    let traceFileURL: URL
    let benchmarkConfiguration: RenderBenchmarkConfiguration

    init(arguments: [String]) throws {
        let values = Array(arguments.dropFirst())
        let tracePath: String
        let warmupIterationCount: Int
        let measuredIterationCount: Int

        guard (1...3).contains(values.count) else {
            throw RenderBenchmarkCommandError.invalidArguments
        }

        tracePath = values[0]
        if values.count >= 2 {
            guard let warmup = Int(values[1]) else {
                throw RenderBenchmarkCommandError.invalidArguments
            }
            warmupIterationCount = warmup
        } else {
            warmupIterationCount =
                RenderBenchmarkConfiguration.defaultWarmupIterationCount
        }
        if values.count == 3 {
            guard let measured = Int(values[2]) else {
                throw RenderBenchmarkCommandError.invalidArguments
            }
            measuredIterationCount = measured
        } else {
            measuredIterationCount =
                RenderBenchmarkConfiguration.defaultMeasuredIterationCount
        }

        self.traceFileURL = URL(fileURLWithPath: tracePath)
            .standardizedFileURL
        self.benchmarkConfiguration = try RenderBenchmarkConfiguration(
            warmupIterationCount: warmupIterationCount,
            measuredIterationCount: measuredIterationCount
        )
    }
}
