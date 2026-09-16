import simd

/// Consumes a selected launcher's fire press and registers one visible projectile before movement begins.
///
/// Mining Game Content aims at the nearest active solid body with an ore deposit, breaking ties by complete identity.
/// Target choice is independent of an entity's removal capability or health.
/// A depleted deposit remains eligible; mining and targeting have separate policies.
/// The initial trajectory leads the target's current velocity and inherits the launcher's velocity.
struct MissileLaunchSystem: System {
    mutating func update(world: inout World, deltaTime: Double) {
        guard deltaTime.isFinite, deltaTime > 0 else {
            return
        }

        let requests = world.playerControlComponents.entities.filter {
            world.playerControlComponents[$0]?.isFireRequested == true
        }
        for actor in requests {
            world.playerControlComponents.update(for: actor) { control in
                control.isFireRequested = false
            }
            guard world.selectedEntityID == actor else {
                continue
            }
            launch(from: actor, in: world)
        }
    }

    private func launch(from actor: EntityID, in world: World) {
        guard let launcher = world.missileLauncherComponents[actor],
              let position = world.positionComponents[actor]?.position,
              let motion = world.motionComponents[actor],
              let body = world.collisionBodyComponents[actor],
              position.isFinite, motion.velocity.isFinite else {
            return
        }

        let direction = aimDirection(
            from: actor,
            position: position,
            velocity: motion.velocity,
            speed: launcher.speed,
            in: world
        )
        let launchPosition = position + direction * (body.radius + launcher.radius)
        let launchVelocity = motion.velocity + direction * launcher.speed
        guard launchPosition.isFinite, launchVelocity.isFinite else {
            return
        }
        _ = Missile(
            in: world,
            ownerEntityID: actor,
            position: launchPosition,
            velocity: launchVelocity,
            radius: launcher.radius,
            lifetime: launcher.lifetime
        )
    }

    private func aimDirection(
        from actor: EntityID,
        position: SIMD3<Double>,
        velocity: SIMD3<Double>,
        speed: Double,
        in world: World
    ) -> SIMD3<Double> {
        let planarVelocity = SIMD2<Double>(velocity.x, velocity.y)
        let fallback = simd_length(planarVelocity) > 0 ? simd_normalize(planarVelocity) : SIMD2<Double>(1, 0)
        guard let target = nearestOreDeposit(to: position, excluding: actor, in: world),
              let targetPosition = world.positionComponents[target]?.position else {
            return SIMD3<Double>(fallback.x, fallback.y, 0)
        }

        let offset = SIMD2<Double>(targetPosition.x - position.x, targetPosition.y - position.y)
        let targetVelocity = world.orbitalRailComponents[target]?.velocity ??
            world.motionComponents[target]?.velocity ?? .zero
        let relativeVelocity = SIMD2<Double>(targetVelocity.x, targetVelocity.y) - planarVelocity
        let flightTime = interceptionTime(offset: offset, velocity: relativeVelocity, speed: speed)
        let lead = offset + relativeVelocity * (flightTime ?? 0)
        let distance = simd_length(lead)
        guard lead.isFinite, distance.isFinite, distance > 0 else {
            return SIMD3<Double>(fallback.x, fallback.y, 0)
        }
        return SIMD3<Double>(lead.x / distance, lead.y / distance, 0)
    }

    private func nearestOreDeposit(
        to position: SIMD3<Double>,
        excluding actor: EntityID,
        in world: World
    ) -> EntityID? {
        var target: EntityID?
        var nearestDistanceSquared = Double.infinity
        for candidate in world.oreDepositComponents.entities where candidate != actor {
            guard world.lifecycleComponents[candidate]?.state == .active,
                  world.collisionBodyComponents[candidate]?.response.isSolid == true,
                  let candidatePosition = world.positionComponents[candidate]?.position else {
                continue
            }
            let offset = SIMD2<Double>(candidatePosition.x - position.x, candidatePosition.y - position.y)
            let distanceSquared = simd_length_squared(offset)
            guard distanceSquared.isFinite else {
                continue
            }
            if distanceSquared < nearestDistanceSquared ||
                (distanceSquared == nearestDistanceSquared && (target.map { candidate < $0 } ?? true)) {
                target = candidate
                nearestDistanceSquared = distanceSquared
            }
        }

        return target
    }

    private func interceptionTime(offset: SIMD2<Double>, velocity: SIMD2<Double>, speed: Double) -> Double? {
        let a = simd_length_squared(velocity) - speed * speed
        let b = 2 * simd_dot(offset, velocity)
        let c = simd_length_squared(offset)
        if abs(a) < 1e-9 {
            let time = -c / b
            return time.isFinite && time > 0 ? time : nil
        }

        let discriminant = b * b - 4 * a * c
        guard discriminant.isFinite, discriminant >= 0 else {
            return nil
        }
        let root = discriminant.squareRoot()
        let near = (-b - root) / (2 * a)
        let far = (-b + root) / (2 * a)
        let first = near.isFinite && near > 0 ? near : Double.infinity
        let second = far.isFinite && far > 0 ? far : Double.infinity
        let time = min(first, second)
        return time.isFinite ? time : nil
    }
}
