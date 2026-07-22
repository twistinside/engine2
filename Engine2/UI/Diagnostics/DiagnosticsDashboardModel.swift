import Observation

/// Five-hertz immutable snapshot sampler for the expanded dashboard.
@MainActor
@Observable
final class DiagnosticsDashboardModel {
    private weak var source: (any PDiagnosticsSnapshotSource)?
    private(set) var presentation: DiagnosticsDashboardPresentation

    init(source: any PDiagnosticsSnapshotSource) {
        self.source = source
        self.presentation = DiagnosticsDashboardPresentation(
            snapshot: source.latestDiagnosticsSnapshot
        )
    }

    func refresh() {
        guard let source else { return }
        presentation = DiagnosticsDashboardPresentation(
            snapshot: source.latestDiagnosticsSnapshot
        )
    }
}
