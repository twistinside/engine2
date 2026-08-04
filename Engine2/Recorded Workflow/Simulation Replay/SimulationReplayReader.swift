import Foundation

/// Reads and validates versioned Simulation replay JSON before runtime construction.
nonisolated struct SimulationReplayReader: Sendable {
    func decode(_ data: Data) throws -> SimulationReplayFile {
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: "Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )
        return try decoder.decode(SimulationReplayFile.self, from: data)
    }

    func read(from url: URL) throws -> SimulationReplayFile {
        try decode(
            Data(contentsOf: url, options: .mappedIfSafe)
        )
    }
}
