import Foundation

/// Reads and validates versioned Render traces from JSON data or files.
nonisolated enum RenderTraceJSONReader {
    /// Decodes only the header so a host can validate compatibility first.
    static func readHeader(from data: Data) throws -> RenderTraceHeader {
        let header = try JSONDecoder()
            .decode(RenderTraceHeaderEnvelope.self, from: data)
            .header
        return header
    }

    /// Decodes one complete trace and rejects unsupported or malformed input.
    static func read(from data: Data) throws -> RenderTrace {
        try JSONDecoder().decode(RenderTrace.self, from: data)
    }

    /// Loads and decodes one complete trace from a file URL.
    static func read(from url: URL) throws -> RenderTrace {
        try read(from: Data(contentsOf: url))
    }
}
