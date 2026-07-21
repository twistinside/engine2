/// Stateless diagnostics consumer used when collection is disabled.
final class NoOpDiagnosticsSink: PDiagnosticsSink {
    func record(_ sample: DiagnosticsSample) {}
}
