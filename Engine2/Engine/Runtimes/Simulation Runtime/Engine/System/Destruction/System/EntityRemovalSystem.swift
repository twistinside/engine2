/// Collects marked entities after every gameplay and effects stage of a Simulation tick.
///
/// The Engine runs this system last, before completed state can be published. Pending identities
/// are collected before removal compacts stores, then destroyed in complete identity order.
struct EntityRemovalSystem: System {
    mutating func update(world: inout World, deltaTime _: Double) {
        let pendingEntities = zip(world.lifecycleComponents.entities, world.lifecycleComponents.dense)
            .filter { $0.1.state == .pendingRemoval }
            .map { $0.0 }
            .sorted()
        for entity in pendingEntities {
            world.destroy(entity)
        }
        world.collisionContacts.removeAll(keepingCapacity: true)
        world.collisionSweeps.removeAll(keepingCapacity: true)
    }
}
