/// Command-line configuration failure before replay work begins.
enum SimulationReplayCommandError: Error {
    case invalidArguments
}

extension SimulationReplayCommandError: CustomStringConvertible {
    var description: String {
        switch self {
        case .invalidArguments:
            "Usage: SimulationReplay <replay.json> "
                + "[--render-trace <trace.json>]"
        }
    }
}
