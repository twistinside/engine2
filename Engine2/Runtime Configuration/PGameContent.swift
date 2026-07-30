/// Game Content surface consumed while a Runtime Assembly builds its graph.
///
/// Consumer code retains ownership of its entity and asset vocabulary. The
/// assembly receives only the Simulation world recipe and policy plus the
/// backend-neutral Render catalog needed to construct independent runtimes.
protocol PGameContent {
    var worldBuilder: any PWorldBuilder { get }
    var simulationConfiguration: SimulationConfiguration { get }
    var renderAssetCatalog: RenderAssetCatalog { get }
}
