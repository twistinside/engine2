/// Advances finite lifetimes and removes expired entities, independent of their other capabilities.
///
/// Run after impact handling so contacts can use the remaining lifetime at the start of the tick.
/// Expiry does not require Destructible, ownership, movement, or a collision body.
struct LifetimeSystem: System {
    mutating func update(world: inout World, deltaTime: Double) {
        guard deltaTime.isFinite, deltaTime > 0 else {
            return
        }

        var expiredEntities: [EntityID] = []
        for entity in world.lifetimeComponents.entities {
            guard let lifetime = world.lifetimeComponents[entity] else {
                continue
            }
            if lifetime.remainingLifetime <= deltaTime {
                expiredEntities.append(entity)
            } else {
                world.lifetimeComponents.update(for: entity) {
                    $0.remainingLifetime -= deltaTime
                }
            }
        }

        for entity in expiredEntities.sorted() {
            world.destroy(entity)
        }
    }
}
