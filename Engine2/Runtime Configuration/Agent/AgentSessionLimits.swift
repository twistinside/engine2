/// Bounded-work and live-process replay-retention policy for an agent session.
///
/// The byte budget counts only retained encoded artifact data or detached raw
/// image data. Swift object overhead and retained Simulation snapshots are not
/// exactly measurable and are deliberately outside this named bound.
nonisolated struct AgentSessionLimits: Equatable, Sendable {
    /// Conservative policy for interactive tool and agent use.
    static let conservativeDefault = AgentSessionLimits()

    let maximumStepCount: SimulationStepCount
    let maximumRetainedResultCount: Int
    let maximumRetainedImageBytes: Int

    /// Creates positive work/count bounds and a nonnegative image-byte budget.
    init(
        maximumStepCount: SimulationStepCount = SimulationStepCount(rawValue: 600),
        maximumRetainedResultCount: Int = 8,
        maximumRetainedImageBytes: Int = 64 * 1_024 * 1_024
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
