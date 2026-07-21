/// One timestamped, typed observation reported by a runtime owner.
struct DiagnosticsSample: Codable, Equatable, Sendable {
    let sessionID: DiagnosticsSessionID
    let timestamp: DiagnosticsTimestamp
    let category: DiagnosticsCategory
    let payload: DiagnosticsSamplePayload
}
