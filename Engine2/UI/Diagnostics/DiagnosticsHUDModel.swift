import Observation

/// MainActor sampler that bounds SwiftUI invalidation to five updates per second.
@MainActor
@Observable
final class DiagnosticsHUDModel {
    private weak var source: (any PDiagnosticsSnapshotSource)?
    private(set) var presentation: DiagnosticsHUDPresentation

    init(source: any PDiagnosticsSnapshotSource) {
        self.source = source
        self.presentation = DiagnosticsHUDPresentation(
            snapshot: source.latestDiagnosticsSnapshot
        )
    }

    /// Pulls one immutable value without observing live runtime internals.
    func refresh() {
        guard let source else { return }
        presentation = DiagnosticsHUDPresentation(
            snapshot: source.latestDiagnosticsSnapshot
        )
    }
}
