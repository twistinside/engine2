/// Example consumer content for the visible Solar System fixture.
///
/// The content pairs its AU-scale world with camera controls expressed at the
/// same scale and a fixed smoke-test rate of one simulated hour per tick. Its
/// perspective camera can therefore orbit and zoom while the production gravity
/// and movement systems advance every physical position, mass, and radius.
struct SolarSystemGameContent: PGameContent {
    let worldBuilder: any PWorldBuilder = SolarSystemWorldBuilder()
    let simulationConfiguration: SimulationConfiguration = .solarSystem
    let renderAssetCatalog: RenderAssetCatalog = .everything
}
