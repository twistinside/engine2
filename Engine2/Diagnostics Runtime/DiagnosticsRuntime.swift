/// App-owned lifecycle boundary for bounded diagnostic sample retention.
///
/// The runtime consumes reported values and publishes immutable snapshots. It
/// never discovers peer runtimes or reads live World, renderer, or GPU state.
@MainActor
final class DiagnosticsRuntime: PDiagnosticsSink, PDiagnosticsSnapshotSource {
    let sessionID: DiagnosticsSessionID

    private var aggregates: [DiagnosticsSampleKind: DiagnosticsAggregateAccumulator] = [:]
    private var recentSamples: DiagnosticsSampleRing
    private(set) var isCollectionEnabled: Bool
    private(set) var totalSamplesReceived = 0

    init(
        sessionID: DiagnosticsSessionID = DiagnosticsSessionID(),
        recentSampleCapacity: Int = 4_096,
        isCollectionEnabled: Bool = true
    ) {
        self.sessionID = sessionID
        self.recentSamples = DiagnosticsSampleRing(capacity: recentSampleCapacity)
        self.isCollectionEnabled = isCollectionEnabled
    }

    var latestDiagnosticsSnapshot: DiagnosticsSnapshot {
        DiagnosticsSnapshot(
            sessionID: sessionID,
            isCollectionEnabled: isCollectionEnabled,
            recentSampleCapacity: recentSamples.capacity,
            totalSamplesReceived: totalSamplesReceived,
            recentSamples: recentSamples.elements,
            aggregates: DiagnosticsSampleKind.allCases.compactMap { kind in
                aggregates[kind]?.snapshot(for: kind)
            }
        )
    }

    func record(_ sample: DiagnosticsSample) {
        guard isCollectionEnabled, sample.sessionID == sessionID else {
            return
        }

        totalSamplesReceived += 1
        recentSamples.append(sample)
        aggregates[sample.payload.kind, default: DiagnosticsAggregateAccumulator()]
            .record(durationNanoseconds: sample.payload.durationNanoseconds)
    }

    /// Enables or disables future collection without altering runtime wiring.
    func setCollectionEnabled(_ isEnabled: Bool) {
        isCollectionEnabled = isEnabled
    }

    /// Clears retained evidence while preserving this capture session identity.
    func reset() {
        recentSamples.removeAll()
        aggregates.removeAll(keepingCapacity: true)
        totalSamplesReceived = 0
    }
}
