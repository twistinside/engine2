import Engine2

/// Game Content surface consumed while a Runtime Assembly builds its graph.
///
/// Consumer packages retain ownership of their entity and asset vocabulary.
/// The assembly receives only the Simulation world recipe and policy plus the
/// backend-neutral Render catalog needed to construct independent runtimes.
public protocol PGameContent {
    var worldBuilder: any PWorldBuilder { get }
    var simulationConfiguration: SimulationConfiguration { get }
    var renderAssetCatalog: RenderAssetCatalog { get }
}
