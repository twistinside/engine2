/// Immutable bounded diagnostics value consumed by UI, export, and tests.
struct DiagnosticsSnapshot: Equatable, Sendable {
    let sessionID: DiagnosticsSessionID
    let isCollectionEnabled: Bool
    let recentSampleCapacity: Int
    let totalSamplesReceived: Int
    let recentSamples: [DiagnosticsSample]
    let aggregates: [DiagnosticsSampleAggregate]
}
