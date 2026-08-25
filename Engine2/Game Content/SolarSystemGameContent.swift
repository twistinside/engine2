/// Example consumer content for the visible Solar System fixture.
///
/// The content pairs its AU-scale world with camera controls expressed at the
/// same scale. Its perspective camera can therefore orbit and zoom without
/// changing any physical position, mass, or radius.
struct SolarSystemGameContent: PGameContent {
    let worldBuilder: any PWorldBuilder = SolarSystemWorldBuilder()
    let simulationConfiguration: SimulationConfiguration = .solarSystem
    let renderAssetCatalog: RenderAssetCatalog = .everything
}
