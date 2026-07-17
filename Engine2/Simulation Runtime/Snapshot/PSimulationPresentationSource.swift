/// Read-only access to the Simulation Runtime's latest completed presentation value.
///
/// Consumers can select the latest snapshot at their own cadence without gaining
/// access to mutable simulation state or the concrete runtime's wider API.
@MainActor
protocol PSimulationPresentationSource: AnyObject {
    var latestPresentationSnapshot: SimulationPresentationSnapshot { get }
}
