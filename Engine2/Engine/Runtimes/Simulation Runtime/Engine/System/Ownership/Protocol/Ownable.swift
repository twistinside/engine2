/// Capability for entity facades attributed to an owner through Simulation-owned state.
protocol Ownable: Entity {
    var ownerEntityID: EntityID { get }
}

extension Ownable {
    var ownerEntityID: EntityID {
        guard let ownership = world.ownershipComponents[id] else {
            fatalError("There is no ownership component for the ownable entity with ID: \(id)")
        }
        return ownership.ownerEntityID
    }
}
