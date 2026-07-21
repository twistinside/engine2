/// In-memory result used by both the process adapter and repeatability tests.
struct DiagnosticsScenarioRunResult: Equatable, Sendable {
    let manifest: DiagnosticsManifest
    let samples: [DiagnosticsSample]
}
