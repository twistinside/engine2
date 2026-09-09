import simd

/// Resolves the earliest solid contact for each fired collision body.
///
/// Ownership optionally excludes the owner, and lifetimes clip contact sweeps to the time both bodies exist.
/// Only Destructible participants are removed; other fired bodies survive their contacts.
/// Fired bodies ignore one another. All sweeps see the bodies present before deferred removal.
/// Run after movement and before LifetimeSystem, bounce, or interaction systems.
struct FireableImpactSystem: System {
    mutating func update(world: inout World, deltaTime: Double) {
        guard deltaTime.isFinite, deltaTime > 0 else {
            return
        }

        var destroyedEntities: Set<EntityID> = []
        for entity in world.fireableComponents.entities {
            let travelFraction = world.lifetimeComponents[entity].map {
                min(1, max(0, $0.remainingLifetime / deltaTime))
            } ?? 1
            guard travelFraction > 0,
                  let target = firstImpact(
                    of: entity, travelFraction: travelFraction, deltaTime: deltaTime, in: world
                  ) else {
                continue
            }
            if world.destructibleComponents[entity] != nil {
                destroyedEntities.insert(entity)
            }
            if world.destructibleComponents[target] != nil {
                destroyedEntities.insert(target)
            }
        }

        for entity in destroyedEntities.sorted() {
            world.destroy(entity)
        }
    }

    private func firstImpact(
        of entity: EntityID,
        travelFraction: Double,
        deltaTime: Double,
        in world: World
    ) -> EntityID? {
        guard let body = world.collisionBodyComponents[entity],
              let previous = world.previousPositionComponents[entity]?.position,
              let current = world.positionComponents[entity]?.position else {
            return nil
        }

        let owner = world.ownershipComponents[entity]?.ownerEntityID
        var hitEntity: EntityID?
        var hitFraction = Double.infinity
        for target in world.collisionBodyComponents.entities where target != owner &&
            world.fireableComponents[target] == nil {
            guard let targetBody = world.collisionBodyComponents[target],
                  let targetPrevious = world.previousPositionComponents[target]?.position,
                  let targetCurrent = world.positionComponents[target]?.position else {
                continue
            }
            let targetTravelFraction = world.lifetimeComponents[target].map {
                min(1, max(0, $0.remainingLifetime / deltaTime))
            } ?? 1
            let sharedTravelFraction = min(travelFraction, targetTravelFraction)
            guard sharedTravelFraction > 0 else {
                continue
            }
            let offset = SIMD2<Double>(previous.x - targetPrevious.x, previous.y - targetPrevious.y)
            let relativePath = SIMD2<Double>(
                (current.x - previous.x) - (targetCurrent.x - targetPrevious.x),
                (current.y - previous.y) - (targetCurrent.y - targetPrevious.y)
            ) * sharedTravelFraction
            guard let fraction = impactFraction(
                offset: offset,
                relativePath: relativePath,
                radius: body.radius + targetBody.radius
            ) else {
                continue
            }

            // Targets may expire at different times; compare fractions of the complete tick.
            let tickFraction = fraction * sharedTravelFraction
            if tickFraction < hitFraction ||
                (tickFraction == hitFraction && (hitEntity.map { target < $0 } ?? true)) {
                hitEntity = target
                hitFraction = tickFraction
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
