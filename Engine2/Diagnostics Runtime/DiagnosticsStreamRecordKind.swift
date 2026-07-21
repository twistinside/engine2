/// Closed line kinds in a diagnostics NDJSON stream.
enum DiagnosticsStreamRecordKind: String, Codable, Sendable {
    case manifest
    case sample
}
