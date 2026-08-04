import Foundation

/// Produces canonical, atomically replaceable Simulation replay JSON.
nonisolated struct SimulationReplayWriter: Sendable {
    func data(for file: SimulationReplayFile) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(file)
    }

    func write(_ file: SimulationReplayFile, to url: URL) throws {
        try data(for: file).write(to: url, options: .atomic)
    }
}
