/// Owns the live Runtime instances and lifecycle ordering for real-time play.
///
/// This first concrete assembly preserves the application's existing topology:
/// one Input Runtime feeds one Simulation Runtime. Future real-time input routes,
/// advance drivers, and output bindings belong here as they gain concrete APIs;
/// they do not become peer-discovery responsibilities of either Runtime.
@MainActor
final class RealtimeAssembly {
    let inputRuntime: InputRuntime
    let simulationRuntime: SimulationRuntime

    init(
        inputRuntime: InputRuntime,
        simulationRuntime: SimulationRuntime
    ) {
        self.inputRuntime = inputRuntime
        self.simulationRuntime = simulationRuntime
    }

    /// Starts producers before consumers so the first Simulation sample belongs
    /// to an active Input Runtime publication session.
    func start() {
        inputRuntime.start()
        simulationRuntime.start()
    }

    /// Stops consumers before producers so no Simulation poll observes a later
    /// Input Runtime lifecycle transition during coordinated shutdown.
    func stop() {
        simulationRuntime.stop()
        inputRuntime.stop()
    }
}
