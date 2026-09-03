/// App-selected composition for the playable mining vertical slice.
///
/// This value owns only content construction, input mapping, Simulation
/// behavior selection, and backend-neutral render descriptions. Runtime
/// lifecycle and authoritative state remain outside Game Content.
struct MiningGameContent: GameContent {
    let inputMappingConfiguration: InputMappingConfiguration = .miningGame
    let simulationBehavior: any SimulationBehavior = MiningSimulationBehavior()
    let worldBuilder: any WorldBuilder = MiningWorldBuilder()
    let simulationConfiguration: SimulationConfiguration = .miningGame
    let renderAssetCatalog: RenderAssetCatalog = .everything
}
