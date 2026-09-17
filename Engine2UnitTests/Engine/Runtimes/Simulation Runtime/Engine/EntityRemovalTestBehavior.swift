@testable import Engine2

/// Exercises expiry and a final Game Content removal request through the production Engine schedule.
struct EntityRemovalTestBehavior: SimulationBehavior {
    let probe: EntityRemovalProbeSystem

    func makeSystemSchedule() -> SimulationSystemSchedule {
        SimulationSystemSchedule(
            postMovement: [LifetimeSystem()],
            prePresentation: [probe]
        )
    }
}
