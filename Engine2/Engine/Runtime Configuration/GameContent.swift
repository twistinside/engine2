/// Game Content surface consumed while a Runtime Assembly builds its graph.
///
/// Consumer code retains ownership of its entity and asset vocabulary. The
/// assembly receives only the Simulation world recipe and policy plus the
/// backend-neutral Render catalog needed to construct independent runtimes.
protocol GameContent {
    var inputMappingConfiguration: InputMappingConfiguration { get }
    var renderAssetCatalog: RenderAssetCatalog { get }
    var simulationBehavior: any SimulationBehavior { get }
    var simulationConfiguration: SimulationConfiguration { get }
    var worldBuilder: any WorldBuilder { get }
}
