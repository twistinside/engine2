import Foundation

/// File locations selected for one command-line Simulation replay.
///
/// The first positional argument is the replay input. Supplying
/// `--render-trace` records every replayed presentation for the independent
/// renderer benchmark without changing Simulation advancement.
struct SimulationReplayCommandConfiguration {
    let replayFileURL: URL
    let renderTraceOutputURL: URL?

    init(arguments: [String]) throws(SimulationReplayCommandError) {
        let values = Array(arguments.dropFirst())

        guard values.count == 1
                || (values.count == 3 && values[1] == "--render-trace")
        else {
            throw .invalidArguments
        }

        self.replayFileURL = URL(fileURLWithPath: values[0])
            .standardizedFileURL
        self.renderTraceOutputURL = values.count == 3
            ? URL(fileURLWithPath: values[2]).standardizedFileURL
            : nil
    }
}
