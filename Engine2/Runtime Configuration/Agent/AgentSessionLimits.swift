/// Bounded-work and live-process replay-retention policy for an agent session.
///
/// The byte budget counts retained encoded artifact data and detached raw image
/// data. A diagnostic outcome retaining both counts both payloads. Swift object
/// overhead and retained Simulation snapshots are not exactly measurable and
/// are deliberately outside this named bound.
nonisolated struct AgentSessionLimits: Equatable, Sendable {
    /// Conservative policy for interactive tool and agent use.
    static let conservative = AgentSessionLimits(
        maximumStepCount: SimulationStepCount(rawValue: 600),
        maximumRetainedResultCount: 8,
        maximumRetainedImageBytes: 64 * 1_024 * 1_024
    )

    let maximumStepCount: SimulationStepCount
    let maximumRetainedResultCount: Int
    let maximumRetainedImageBytes: Int

    /// Creates positive work/count bounds and a nonnegative image-byte budget.
    init(
        maximumStepCount: SimulationStepCount,
        maximumRetainedResultCount: Int,
        maximumRetainedImageBytes: Int
    ) {
        precondition(
            maximumRetainedResultCount > 0,
            "An agent session must retain space for at least one result."
        )
        precondition(
            maximumRetainedImageBytes >= 0,
            "Agent retained-image budget cannot be negative."
        )

        self.maximumStepCount = maximumStepCount
        self.maximumRetainedResultCount = maximumRetainedResultCount
        self.maximumRetainedImageBytes = maximumRetainedImageBytes
    }
}
