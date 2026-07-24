/// Narrow App-owned capability for capturing the latest real-time presentation.
///
/// Implementations select an immutable Simulation publication and matching
/// output viewpoint without exposing either source or the offscreen Render
/// Runtime to the caller.
@MainActor
protocol PRealtimeSnapshotCaptureTarget: AnyObject {
    func capture(
        _ request: RealtimeSnapshotCaptureRequest
    ) async -> RealtimeSnapshotCaptureOutcome
}
