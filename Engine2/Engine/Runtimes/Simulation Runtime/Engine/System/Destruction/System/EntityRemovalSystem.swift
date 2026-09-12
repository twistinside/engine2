/// Collects marked entities after every gameplay and effects stage of a Simulation tick.
///
/// The Engine runs this system last, before completed state can be published. Sorted identities
/// make collection deterministic while the copied list keeps component compaction safe.
struct EntityRemovalSystem: System {
    mutating func update(world: inout World, deltaTime _: Double) {
        for entity in world.pendingRemovalComponents.entities.sorted() {
            world.destroy(entity)
        }
        world.fireableCollisions.removeAll(keepingCapacity: true)
    }
}
