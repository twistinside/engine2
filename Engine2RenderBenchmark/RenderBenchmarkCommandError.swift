/// Command-line configuration failure before Render construction begins.
enum RenderBenchmarkCommandError: Error {
    case incompatibleContent(RecordingContentIdentifier)
    case invalidArguments
}

extension RenderBenchmarkCommandError: CustomStringConvertible {
    var description: String {
        switch self {
        case let .incompatibleContent(identifier):
            "The Render trace records unsupported content "
                + "\(identifier.rawValue)."

        case .invalidArguments:
            "Usage: RenderBenchmark <trace.json> "
                + "[warm-up-iterations] [measured-iterations]"
        }
    }
}
