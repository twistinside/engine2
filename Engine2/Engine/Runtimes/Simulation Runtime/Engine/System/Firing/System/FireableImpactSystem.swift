/// Applies fired-body impact policy to contacts captured by FireableCollisionSystem.
///
/// Destructible participants are marked for the final EntityRemovalSystem. Every captured contact
/// receives a response, including multiple fired bodies hitting the same target during one tick.
/// This system leaves collision geometry and structural removal to their respective systems.
struct FireableImpactSystem: System {
    mutating func update(world: inout World, deltaTime: Double) {
        guard deltaTime.isFinite, deltaTime > 0 else {
            return
        }

        for contact in world.fireableCollisions {
            if world.destructibleComponents[contact.entityID] != nil {
                world.entity(for: contact.entityID)?.markForRemoval()
            }
            if world.destructibleComponents[contact.targetEntityID] != nil {
                world.entity(for: contact.targetEntityID)?.markForRemoval()
            }
        }
    }
}
