/// Policy for elapsed whole-step debt beyond one real-time wake's work cap.
nonisolated enum RealtimeBacklogTreatment: Equatable, Sendable {
    /// Retain excess elapsed time so later wakes can eventually catch up.
    case preserve

    /// Drop excess elapsed time so overload cannot create unbounded latency.
    case discardOverflow
}
