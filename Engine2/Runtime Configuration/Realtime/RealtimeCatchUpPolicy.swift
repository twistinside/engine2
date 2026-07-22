/// Bounded real-time catch-up behavior selected by an App configuration.
///
/// The cap limits one wake's indivisible Simulation request. Backlog treatment
/// decides whether additional whole-step wall-time debt survives that wake; it
/// never changes Simulation tick identity or skips an authoritative tick.
nonisolated struct RealtimeCatchUpPolicy: Equatable, Sendable {
    /// Responsive default for the current MainActor-hosted interactive App.
    static let interactive = RealtimeCatchUpPolicy(
        maximumStepsPerWake: SimulationStepCount(rawValue: 4),
        backlogTreatment: .discardOverflow
    )

    let maximumStepsPerWake: SimulationStepCount
    let backlogTreatment: RealtimeBacklogTreatment

    init(
        maximumStepsPerWake: SimulationStepCount,
        backlogTreatment: RealtimeBacklogTreatment
    ) {
        self.maximumStepsPerWake = maximumStepsPerWake
        self.backlogTreatment = backlogTreatment
    }
}
