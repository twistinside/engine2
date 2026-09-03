/// Neutral Simulation behavior used by basic scenes and focused runtime tests.
struct StandardSimulationBehavior: SimulationBehavior {
    func makeSystemSchedule() -> SimulationSystemSchedule {
        .empty
    }
}
