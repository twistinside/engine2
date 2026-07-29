import Engine2
import Engine2AssemblySupport
/// Bounded real-time catch-up behavior selected by an App configuration.
///
/// The cap limits one wake's indivisible Simulation request. Backlog treatment
/// decides whether additional whole-step wall-time debt survives that wake; it
/// never changes Simulation tick identity or skips an authoritative tick.
public nonisolated struct RealtimeCatchUpPolicy: Equatable, Sendable {
    /// Responsive default for the current MainActor-hosted interactive App.
    public static let interactive = Self(
        maximumStepsPerWake: SimulationStepCount(rawValue: 4),
        backlogTreatment: .discardOverflow
    )

    public let maximumStepsPerWake: SimulationStepCount
    public let backlogTreatment: RealtimeBacklogTreatment

    public init(
        maximumStepsPerWake: SimulationStepCount,
        backlogTreatment: RealtimeBacklogTreatment
    ) {
        self.maximumStepsPerWake = maximumStepsPerWake
        self.backlogTreatment = backlogTreatment
    }
}
