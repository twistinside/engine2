import simd

/// Resolves the earliest planar swept-sphere collision for each dynamic body.
///
/// Rail velocity participates in the relative bounce calculation. The dynamic
/// body is placed on the obstacle's final contact boundary, preventing the
/// discrete post-movement position from remaining embedded.
struct SweptCollisionSystem: System {
    mutating func update(world: inout World, deltaTime: Double) {
        guard deltaTime.isFinite, deltaTime > 0 else {
            return
        }

        let dynamicEntities = world.motionComponents.entities
        for entity in dynamicEntities where world.collisionBodyComponents[entity] != nil &&
            world.fireableComponents[entity] == nil {
            resolveEarliestCollision(for: entity, in: world)
        }
    }

    private func resolveEarliestCollision(for entity: EntityID, in world: World) {
        guard let body = world.collisionBodyComponents[entity],
              let previousPosition = world.previousPositionComponents[entity]?.position,
              let currentPosition = world.positionComponents[entity]?.position else {
            return
        }

        var hitEntity: EntityID?
        var hitFraction = Double.infinity
        var hitNormal = SIMD2<Double>.zero

        for obstacle in world.collisionBodyComponents.entities where obstacle != entity &&
            world.fireableComponents[obstacle] == nil {
            guard let obstacleBody = world.collisionBodyComponents[obstacle],
                  let obstaclePrevious = world.previousPositionComponents[obstacle]?.position,
                  let obstacleCurrent = world.positionComponents[obstacle]?.position,
                  let collision = collision(
                    movingFrom: SIMD2<Double>(previousPosition.x, previousPosition.y),
                    movingTo: SIMD2<Double>(currentPosition.x, currentPosition.y),
                    obstacleFrom: SIMD2<Double>(obstaclePrevious.x, obstaclePrevious.y),
                    obstacleTo: SIMD2<Double>(obstacleCurrent.x, obstacleCurrent.y),
                    combinedRadius: body.radius + obstacleBody.radius
                  ) else {
                continue
            }

            let winsIdentityTie = hitEntity.map { obstacle < $0 } ?? true
            if collision.fraction < hitFraction ||
                (collision.fraction == hitFraction && winsIdentityTie) {
                hitEntity = obstacle
                hitFraction = collision.fraction
                hitNormal = collision.normal
            }
        }

        guard let hitEntity,
              let obstacleBody = world.collisionBodyComponents[hitEntity],
              let obstaclePosition = world.positionComponents[hitEntity]?.position,
              let motion = world.motionComponents[entity] else {
            return
        }

        let combinedRadius = body.radius + obstacleBody.radius
        world.positionComponents.update(for: entity) { position in
            position.position.x = obstaclePosition.x + hitNormal.x * combinedRadius
            position.position.y = obstaclePosition.y + hitNormal.y * combinedRadius
        }

        let obstacleVelocity = velocity(of: hitEntity, in: world)
        let relativeVelocity = SIMD2<Double>(
            motion.velocity.x - obstacleVelocity.x,
            motion.velocity.y - obstacleVelocity.y
        )
        let normalVelocity = simd_dot(relativeVelocity, hitNormal)
        guard normalVelocity < 0 else {
            return
        }

        let restitution = min(body.restitution, obstacleBody.restitution)
        let reflectedVelocity = relativeVelocity - (1 + restitution) * normalVelocity * hitNormal
        world.motionComponents.update(for: entity) { component in
            component.velocity.x = obstacleVelocity.x + reflectedVelocity.x
            component.velocity.y = obstacleVelocity.y + reflectedVelocity.y
        }
    }

    private func collision(
        movingFrom: SIMD2<Double>,
        movingTo: SIMD2<Double>,
        obstacleFrom: SIMD2<Double>,
        obstacleTo: SIMD2<Double>,
        combinedRadius: Double
    ) -> (fraction: Double, normal: SIMD2<Double>)? {
        let initialOffset = movingFrom - obstacleFrom
        let relativePath = (movingTo - movingFrom) - (obstacleTo - obstacleFrom)
        let radiusSquared = combinedRadius * combinedRadius
        let initialDistanceSquared = simd_length_squared(initialOffset)

        let fraction: Double
        if initialDistanceSquared <= radiusSquared {
            fraction = 0
        } else {
            let a = simd_length_squared(relativePath)
            guard a.isFinite, a > 0 else {
                return nil
            }
            let b = 2 * simd_dot(initialOffset, relativePath)
            let c = initialDistanceSquared - radiusSquared
            let discriminant = b * b - 4 * a * c
            guard discriminant.isFinite, discriminant >= 0 else {
                return nil
            }

            let nearFraction = (-b - discriminant.squareRoot()) / (2 * a)
            guard nearFraction >= 0, nearFraction <= 1 else {
                return nil
            }
            fraction = nearFraction
        }

        let impactOffset = initialOffset + relativePath * fraction
        let impactDistance = simd_length(impactOffset)
        if impactDistance.isFinite, impactDistance > 0 {
            return (fraction, impactOffset / impactDistance)
        }

        let pathLength = simd_length(relativePath)
        guard pathLength.isFinite, pathLength > 0 else {
            return (fraction, SIMD2<Double>(1, 0))
        }
        return (fraction, -relativePath / pathLength)
    }

    private func velocity(of entity: EntityID, in world: World) -> SIMD2<Double> {
        if let rail = world.orbitalRailComponents[entity] {
            return SIMD2<Double>(rail.velocity.x, rail.velocity.y)
        }
        if let motion = world.motionComponents[entity] {
            return SIMD2<Double>(motion.velocity.x, motion.velocity.y)
        }
        return .zero
    }
}
