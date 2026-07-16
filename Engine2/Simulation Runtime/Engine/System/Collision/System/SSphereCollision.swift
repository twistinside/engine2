//
//  SSphereCollision.swift
//  Engine2
//
//  Created by Codex on 7/15/26.
//

import simd

/// Resolves overlapping movable bounding spheres with equal-mass elastic response.
///
/// This intentionally starts with an O(n²) all-pairs scan. It is suitable for
/// validating ECS ownership and scheduling, but it is not yet a broad-phase
/// spatial index and it does not perform swept collision detection.
struct SSphereCollision: PSystem {
    private static let coincidentCenterEpsilon: Float = 0.000_001

    func update(world: inout World, deltaTime _: Float) {
        let entities = world.boundingSphereComponents.entities

        guard entities.count > 1 else {
            return
        }

        // Visit every unordered pair once. The bounding-sphere store drives
        // iteration; incomplete position or motion rows are ignored safely.
        for firstIndex in 0..<(entities.count - 1) {
            for secondIndex in (firstIndex + 1)..<entities.count {
                resolve(
                    entities[firstIndex],
                    against: entities[secondIndex],
                    in: &world
                )
            }
        }
    }

    private func resolve(
        _ firstEntity: EntityID,
        against secondEntity: EntityID,
        in world: inout World
    ) {
        guard let firstSphere = world.boundingSphereComponents[firstEntity],
              let secondSphere = world.boundingSphereComponents[secondEntity],
              let firstPosition = world.positionComponents[firstEntity],
              let secondPosition = world.positionComponents[secondEntity],
              let firstMotion = world.motionComponents[firstEntity],
              let secondMotion = world.motionComponents[secondEntity]
        else {
            return
        }

        let centerDelta = secondPosition.position - firstPosition.position
        let radiusSum = firstSphere.radius + secondSphere.radius
        let distanceSquared = simd_length_squared(centerDelta)

        // Touching spheres count as a collision so an approaching pair can
        // reverse before the following movement step creates visible overlap.
        guard distanceSquared <= radiusSum * radiusSum else {
            return
        }

        let distance: Float
        let normal: SIMD3<Float>

        if distanceSquared > Self.coincidentCenterEpsilon {
            distance = sqrt(distanceSquared)
            normal = centerDelta / distance
        } else {
            distance = 0

            // Coincident centers do not define a geometric normal. Prefer the
            // direction in which the first entity is moving into the second;
            // use a stable axis if both velocities are also identical.
            let relativeHeading = firstMotion.velocity - secondMotion.velocity
            if simd_length_squared(relativeHeading) > Self.coincidentCenterEpsilon {
                normal = simd_normalize(relativeHeading)
            } else {
                normal = SIMD3<Float>(1, 0, 0)
            }
        }

        // Split penetration correction evenly because this first pass treats
        // both entities as equal-mass movable bodies.
        let penetration = radiusSum - distance
        if penetration > 0 {
            let correction = normal * (penetration * 0.5)
            world.positionComponents.update(for: firstEntity) { position in
                position.position -= correction
            }
            world.positionComponents.update(for: secondEntity) { position in
                position.position += correction
            }
        }

        let relativeVelocity = secondMotion.velocity - firstMotion.velocity
        let closingSpeed = simd_dot(relativeVelocity, normal)

        // Positional correction is still required for separating overlaps, but
        // applying another impulse would make already-separating bodies stick.
        guard closingSpeed < 0 else {
            return
        }

        // For restitution 1 and equal unit masses, the scalar impulse reduces
        // to the negated closing speed. This exchanges the normal components
        // while preserving tangential motion.
        let impulse = normal * -closingSpeed
        world.motionComponents.update(for: firstEntity) { motion in
            motion.velocity -= impulse
        }
        world.motionComponents.update(for: secondEntity) { motion in
            motion.velocity += impulse
        }
    }
}
