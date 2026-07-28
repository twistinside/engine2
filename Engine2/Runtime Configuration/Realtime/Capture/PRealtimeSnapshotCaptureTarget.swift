/// Narrow assembly-owned capability for capturing the latest real-time presentation.
///
/// Implementations select an immutable Simulation publication and derive the
/// exact offscreen request camera from that snapshot without exposing either
/// the source or the offscreen Render Runtime to the caller.
protocol PRealtimeSnapshotCaptureTarget: AnyObject {
    func capture(_ request: RealtimeSnapshotCaptureRequest) async -> RealtimeSnapshotCaptureOutcome
}
