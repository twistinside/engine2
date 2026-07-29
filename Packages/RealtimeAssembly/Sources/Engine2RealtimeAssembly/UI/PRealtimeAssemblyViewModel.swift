import Engine2
import Engine2AssemblySupport
/// Narrow real-time assembly surface consumed by its topology-specific content.
///
/// The interface groups one coherent view dependency without exposing exact
/// Simulation advancement, world replacement, cadence-driver mutation, or
/// lifecycle operations to child views.
protocol PRealtimeAssemblyViewModel {
    /// Game Content catalog selected for screen rendering.
    var renderAssetCatalog: RenderAssetCatalog { get }

    /// Latest completed Simulation presentation consumed by the screen.
    var presentationSource: any PSimulationPresentationSource { get }

    /// Platform-event ingress connected to the Input Runtime.
    var inputSink: any PInputEventSink { get }

    /// Read-only copy of Simulation-consumed input diagnostics.
    var inputHistoryEntries: [InputHistoryEntry] { get }

    /// Whether advancement is both enabled by policy and currently running.
    var isAdvancementActive: Bool { get }

    /// Toggles only the assembly-owned advancement policy.
    func toggleAdvancement()
}
