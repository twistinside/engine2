/// Advances finite lifetimes and marks expired entities for final collection.
///
/// Run after impact handling so contacts can use the remaining lifetime at the start of the tick.
/// Expiry does not require Destructible, ownership, movement, or a collision body.
/// Rows remain available until the Engine's final EntityRemovalSystem.
struct LifetimeSystem: System {
    mutating func update(world: inout World, deltaTime: Double) {
        guard deltaTime.isFinite, deltaTime > 0 else {
            return
        }

        for entity in world.lifetimeComponents.entities {
            guard let lifetime = world.lifetimeComponents[entity] else {
                continue
            }
            let remainingLifetime = max(0, lifetime.remainingLifetime - deltaTime)
            world.lifetimeComponents.update(for: entity) {
                $0.remainingLifetime = remainingLifetime
            }
            if remainingLifetime == 0 {
                world.entity(for: entity)?.markForRemoval()
            }
        }
    }
}
