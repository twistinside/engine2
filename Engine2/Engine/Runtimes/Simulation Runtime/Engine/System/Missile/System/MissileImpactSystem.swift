import simd

/// Removes missiles on their earliest solid impact and removes bodies marked destructible.
///
/// Run after movement and before bounce or interaction systems. Contacts use relative swept motion,
/// including a shortened final flight interval. Every sweep sees the bodies present before removal,
/// so missiles that hit the same body in one tick are all consumed. Removal follows store traversal.
struct MissileImpactSystem: System {
    mutating func update(world: inout World, deltaTime: Double) {
        guard deltaTime.isFinite, deltaTime > 0 else {
            return
        }

        var destroyedEntities: Set<EntityID> = []
        for entity in world.missileComponents.entities {
            guard let missile = world.missileComponents[entity] else {
                continue
            }
            let travelFraction = min(1, max(0, missile.remainingLifetime / deltaTime))
            if travelFraction > 0,
               let target = firstImpact(of: entity, missile: missile, travelFraction: travelFraction, in: world) {
                destroyedEntities.insert(entity)
                if world.destructibleComponents[target] != nil {
                    destroyedEntities.insert(target)
                }
            } else if missile.remainingLifetime <= deltaTime {
                destroyedEntities.insert(entity)
            } else {
                world.missileComponents.update(for: entity) { component in
                    component.remainingLifetime -= deltaTime
                }
            }
        }

        for entity in destroyedEntities.sorted() {
            world.destroy(entity)
        }
    }

    private func firstImpact(
        of entity: EntityID,
        missile: MissileComponent,
        travelFraction: Double,
        in world: World
    ) -> EntityID? {
        guard let body = world.collisionBodyComponents[entity],
              let previous = world.previousPositionComponents[entity]?.position,
              let current = world.positionComponents[entity]?.position else {
            return nil
        }

        var hitEntity: EntityID?
        var hitFraction = Double.infinity
        for target in world.collisionBodyComponents.entities where target != missile.ownerEntityID &&
            world.missileComponents[target] == nil {
            guard let targetBody = world.collisionBodyComponents[target],
                  let targetPrevious = world.previousPositionComponents[target]?.position,
                  let targetCurrent = world.positionComponents[target]?.position else {
                continue
            }
            let offset = SIMD2<Double>(previous.x - targetPrevious.x, previous.y - targetPrevious.y)
            let relativePath = SIMD2<Double>(
                (current.x - previous.x) - (targetCurrent.x - targetPrevious.x),
                (current.y - previous.y) - (targetCurrent.y - targetPrevious.y)
            ) * travelFraction
            guard let fraction = impactFraction(
                offset: offset,
                relativePath: relativePath,
                radius: body.radius + targetBody.radius
            ) else {
                continue
            }

            if fraction < hitFraction ||
                (fraction == hitFraction && (hitEntity.map { target < $0 } ?? true)) {
                hitEntity = target
                hitFraction = fraction
            }
        }
        return hitEntity
    }

    private func impactFraction(offset: SIMD2<Double>, relativePath: SIMD2<Double>, radius: Double) -> Double? {
        guard offset.isFinite, relativePath.isFinite, radius.isFinite else {
            return nil
        }
        let c = simd_length_squared(offset) - radius * radius
        if c <= 0 {
            return 0
        }

        let a = simd_length_squared(relativePath)
        guard a.isFinite, a > 0 else {
            return nil
        }
        let b = 2 * simd_dot(offset, relativePath)
        let discriminant = b * b - 4 * a * c
        guard discriminant.isFinite, discriminant >= 0 else {
            return nil
        }
        let fraction = (-b - discriminant.squareRoot()) / (2 * a)
        return fraction >= 0 && fraction <= 1 ? fraction : nil
    }
}
