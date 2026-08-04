import Foundation

/// Writes validated Render traces in deterministic schema-v1 JSON.
nonisolated enum RenderTraceJSONWriter {
    /// Encodes one trace with stable key ordering for reviewable artifacts.
    static func data(for trace: RenderTrace) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(trace)
    }

    /// Atomically replaces or creates one trace file.
    static func write(_ trace: RenderTrace, to url: URL) throws {
        try data(for: trace).write(to: url, options: .atomic)
    }
}
