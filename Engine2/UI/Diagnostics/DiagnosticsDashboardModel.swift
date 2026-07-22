import Observation

/// Five-hertz immutable snapshot sampler for the expanded dashboard.
@MainActor
@Observable
final class DiagnosticsDashboardModel {
    private weak var controller: (any PDiagnosticsController)?
    private var latestSnapshot: DiagnosticsSnapshot
    private(set) var presentation: DiagnosticsDashboardPresentation
    private(set) var isPaused = false
    private(set) var scrubFraction = 1.0

    init(controller: any PDiagnosticsController) {
        let snapshot = controller.latestDiagnosticsSnapshot
        self.controller = controller
        self.latestSnapshot = snapshot
        self.presentation = DiagnosticsDashboardPresentation(
            snapshot: snapshot
        )
    }

    func refresh() {
        guard !isPaused, let controller else { return }
        latestSnapshot = controller.latestDiagnosticsSnapshot
        scrubFraction = 1
        rebuildPresentation()
    }

    func togglePaused() {
        isPaused.toggle()
        if !isPaused {
            refresh()
        }
    }

    func setScrubFraction(_ fraction: Double) {
        scrubFraction = min(max(fraction, 0), 1)
        isPaused = true
        rebuildPresentation()
    }

    func startCaptureSession() {
        controller?.reset()
        controller?.setCollectionEnabled(true)
        latestSnapshot = controller?.latestDiagnosticsSnapshot ?? latestSnapshot
        isPaused = false
        scrubFraction = 1
        rebuildPresentation()
    }

    func stopCaptureSession() {
        controller?.setCollectionEnabled(false)
        latestSnapshot = controller?.latestDiagnosticsSnapshot ?? latestSnapshot
        rebuildPresentation()
    }

    func reset() {
        controller?.reset()
        latestSnapshot = controller?.latestDiagnosticsSnapshot ?? latestSnapshot
        scrubFraction = 1
        rebuildPresentation()
    }

    func exportSnapshot() -> DiagnosticsSnapshot {
        latestSnapshot
    }

    private func rebuildPresentation() {
        let count = Int((Double(latestSnapshot.recentSamples.count) * scrubFraction).rounded())
        let boundedCount = min(max(count, 0), latestSnapshot.recentSamples.count)
        let visibleSnapshot = DiagnosticsSnapshot(
            sessionID: latestSnapshot.sessionID,
            isCollectionEnabled: latestSnapshot.isCollectionEnabled,
            recentSampleCapacity: latestSnapshot.recentSampleCapacity,
            totalSamplesReceived: latestSnapshot.totalSamplesReceived,
            recentSamples: Array(latestSnapshot.recentSamples.prefix(boundedCount)),
            aggregates: latestSnapshot.aggregates
        )
        presentation = DiagnosticsDashboardPresentation(snapshot: visibleSnapshot)
    }
}
