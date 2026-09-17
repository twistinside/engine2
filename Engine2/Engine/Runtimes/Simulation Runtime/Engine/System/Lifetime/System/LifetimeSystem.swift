/// Advances finite lifetimes and marks expired entities for final collection.
///
/// Run after impact handling so contacts can use the remaining lifetime at the start of the tick.
/// Every entity inherits Destructible; expiry requires no ownership, movement, or collision body.
/// Rows remain available until the Engine's final EntityRemovalSystem.
struct LifetimeSystem: System {
    mutating func update(world: inout World, deltaTime: Double) {
        guard deltaTime.isFinite, deltaTime > 0 else {
            return
        }

        for entity in world.components[LifetimeComponent.self].entities {
            guard let lifetime = world.components[LifetimeComponent.self][entity] else {
                continue
            }
            let remainingLifetime = max(0, lifetime.remainingLifetime - deltaTime)
            world.components[LifetimeComponent.self].update(for: entity) {
                $0.remainingLifetime = remainingLifetime
            }
            if remainingLifetime == 0 {
                world.components[DestructibleComponent.self].update(for: entity) {
                    $0.state = .pendingRemoval
                }
            }
        }
    }
}
