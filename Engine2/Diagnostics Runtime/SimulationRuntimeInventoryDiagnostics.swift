/// Ordered schedule and storage inventory for one constructed Simulation world.
struct SimulationRuntimeInventoryDiagnostics: Codable, Equatable, Sendable {
    let alwaysSystemIDs: [SimulationSystemID]
    let simulationSystemIDs: [SimulationSystemID]
    let componentStores: [ComponentStoreInventory]
    let presentationEntityCount: Int
}
