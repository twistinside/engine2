/// Owns one caller-driven Simulation Runtime without an automatic cadence.
///
/// The assembly deliberately exposes the Runtime's narrow advance and
/// presentation capabilities while retaining the concrete Runtime for current
/// App tooling. With no driver in this topology, silence means no progress.
@MainActor
final class ManualAssembly {
    let simulationRuntime: SimulationRuntime

    init(simulationRuntime: SimulationRuntime) {
        self.simulationRuntime = simulationRuntime
    }

    /// Narrow capability used by callers that may live outside MainActor.
    nonisolated var advanceTarget: any PSimulationAdvanceTarget {
        simulationRuntime
    }

    /// Latest-value presentation capability for independently paced consumers.
    var presentationSource: any PSimulationPresentationSource {
        simulationRuntime
    }
}
