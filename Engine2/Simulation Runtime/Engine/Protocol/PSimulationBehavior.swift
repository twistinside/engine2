/// Controlled Game Content extension point for Simulation-owned system scheduling.
///
/// A behavior supplies fresh system values for one Engine construction. It cannot
/// replace the Engine's foundational systems or reorder work across stage boundaries.
protocol PSimulationBehavior {
    func makeSystemSchedule() -> SimulationSystemSchedule
}
