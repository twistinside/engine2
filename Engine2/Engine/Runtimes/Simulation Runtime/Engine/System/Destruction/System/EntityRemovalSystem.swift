/// Collects marked entities after every gameplay and effects stage of a Simulation tick.
///
/// The Engine runs this system last, before completed state can be published. The registered
/// entity snapshot preserves identity order and keeps removal safe while the World changes.
struct EntityRemovalSystem: System {
    mutating func update(world: inout World, deltaTime _: Double) {
        for entity in world.registeredEntities where entity.lifecycleState == .pendingRemoval {
            world.destroy(entity.id)
        }
        world.collisionContacts.removeAll(keepingCapacity: true)
        world.collisionSweeps.removeAll(keepingCapacity: true)
    }
}
