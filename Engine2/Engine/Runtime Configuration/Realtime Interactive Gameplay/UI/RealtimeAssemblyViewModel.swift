/// Narrow real-time assembly surface consumed by its topology-specific content.
///
/// The interface groups one coherent view dependency without exposing exact
/// Simulation advancement, world replacement, cadence-driver mutation, or
/// lifecycle operations to child views.
protocol RealtimeAssemblyViewModel {
    /// Game Content catalog selected for screen rendering.
    var renderAssetCatalog: RenderAssetCatalog { get }

    /// Latest completed Simulation presentation consumed by the screen.
    var presentationSource: any SimulationPresentationSource { get }

    /// Platform-event ingress connected to the Input Runtime.
    var inputSink: any InputEventSink { get }

    /// Selected live entity exposed through capability protocols for inspection.
    var selectedEntitySource: any SelectedEntitySource { get }

    /// Whether advancement is both enabled by policy and currently running.
    var isAdvancementActive: Bool { get }

    /// Toggles only the assembly-owned advancement policy.
    func toggleAdvancement()

    /// Requests an assembly-coordinated rebuild of the current session.
    func restartSession()

    /// Stages a selected craft maneuver for the next complete Simulation tick.
    func requestOrbitCircularization(for entityID: EntityID)
}
