/// Read-only capability exposing the latest bounded diagnostics value.
protocol PDiagnosticsSnapshotSource: AnyObject {
    var latestDiagnosticsSnapshot: DiagnosticsSnapshot { get }
}
