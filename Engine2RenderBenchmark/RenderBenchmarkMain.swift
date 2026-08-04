import Darwin
import Foundation
import Metal

/// Process entry point for the renderer-only recorded-trace benchmark.
@main
struct RenderBenchmarkMain {
    static func main() {
        do {
            let command = try RenderBenchmarkCommandConfiguration(
                arguments: CommandLine.arguments
            )
            let traceData = try Data(
                contentsOf: command.traceFileURL,
                options: .mappedIfSafe
            )
            let traceHeader = try RenderTraceJSONReader.readHeader(
                from: traceData
            )
            guard traceHeader.contentIdentifier == BasicGameRecording.contentIdentifier else {
                throw RenderBenchmarkCommandError.incompatibleContent(
                    traceHeader.contentIdentifier
                )
            }
            let trace = try RenderTraceJSONReader.read(from: traceData)

            var frames: [RenderBenchmarkFrame] = []
            frames.reserveCapacity(trace.frames.count)
            for input in trace.renderInputs {
                let clearColor = input.clearColor
                frames.append(
                    RenderBenchmarkFrame(
                        sequence: input.sequence,
                        presentationSnapshot: input.presentationSnapshot,
                        viewpoint: input.viewpoint,
                        settings: input.settings,
                        clearColor: MTLClearColor(
                            red: clearColor.red,
                            green: clearColor.green,
                            blue: clearColor.blue,
                            alpha: clearColor.alpha
                        )
                    )
                )
            }

            let runner = try RenderBenchmarkRunner(
                renderAssetCatalog: .everything,
                frames: frames,
                configuration: command.benchmarkConfiguration
            )
            print(try runner.run())
        } catch {
            FileHandle.standardError.write(
                Data("Engine2 Render benchmark failed: \(error)\n".utf8)
            )
            Darwin.exit(EXIT_FAILURE)
        }
    }
}
