/// Neutral Simulation behavior used by basic scenes and focused runtime tests.
struct StandardSimulationBehavior: PSimulationBehavior {
    func makeSystemSchedule() -> SimulationSystemSchedule {
        .empty
    }
}
