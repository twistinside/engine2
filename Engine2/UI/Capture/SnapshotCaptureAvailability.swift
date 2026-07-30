/// Construction result for the assembly-owned real-time snapshot capability.
///
/// An available model always owns a capture target. An unavailable model
/// instead retains the concrete open-ended initialization diagnostic that
/// should be presented when capture is requested.
enum SnapshotCaptureAvailability {
    case available(any PRealtimeSnapshotCaptureTarget)
    case unavailable(reason: String)
}
