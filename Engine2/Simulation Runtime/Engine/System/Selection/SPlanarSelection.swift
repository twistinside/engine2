import simd

/// Resolves one semantic screen press against selectable spherical bounds.
///
/// The system runs before movement, so the camera and component positions match
/// the latest completed presentation the user clicked. Nearest distance wins;
/// full entity identity provides a deterministic tie-breaker.
struct SPlanarSelection: PSystem {
    mutating func update(world: inout World, deltaTime _: Double) {
        guard let press = world.input.selectionPress else {
            return
        }

        guard let ray = selectionRay(for: press, camera: world.camera) else {
            world.select(nil)
            return
        }

        world.select(nearestHit(in: world, rayOrigin: ray.origin, rayDirection: ray.direction))
    }

    private func selectionRay(
        for press: SelectionPress,
        camera: Camera
    ) -> (origin: SIMD3<Double>, direction: SIMD3<Double>)? {
        let normalized = press.normalizedPosition
        let clipX = normalized.x * 2 - 1
        let clipY = normalized.y * 2 - 1
        let inverseViewProjection = simd_inverse(
            camera.viewProjectionMatrix(aspectRatio: press.aspectRatio)
        )
        guard inverseViewProjection.hasFiniteElements else {
            return nil
        }

        let nearPoint = inverseViewProjection * SIMD4<Float>(clipX, clipY, 0, 1)
        let farPoint = inverseViewProjection * SIMD4<Float>(clipX, clipY, 1, 1)
        guard nearPoint.isFinite,
              farPoint.isFinite,
              nearPoint.w != 0,
              farPoint.w != 0 else {
            return nil
        }

        let nearWorld = SIMD3<Double>(
            Double(nearPoint.x),
            Double(nearPoint.y),
            Double(nearPoint.z)
        ) / Double(nearPoint.w)
        let farWorld = SIMD3<Double>(
            Double(farPoint.x),
            Double(farPoint.y),
            Double(farPoint.z)
        ) / Double(farPoint.w)
        let directionCandidate = farWorld - nearWorld
        let directionLength = simd_length(directionCandidate)
        guard nearWorld.isFinite,
              directionCandidate.isFinite,
              directionLength.isFinite,
              directionLength > 0 else {
            return nil
        }

        return (nearWorld, directionCandidate / directionLength)
    }

    private func nearestHit(
        in world: World,
        rayOrigin: SIMD3<Double>,
        rayDirection: SIMD3<Double>
    ) -> EntityID? {
        var nearestEntity: EntityID?
        var nearestDistance = Double.infinity

        for entity in world.selectionBoundsComponents.entities {
            guard world.selectableComponents[entity] != nil,
                  let bounds = world.selectionBoundsComponents[entity],
                  let position = world.positionComponents[entity]?.position,
                  let distance = hitDistance(
                    rayOrigin: rayOrigin,
                    rayDirection: rayDirection,
                    center: position,
                    radius: bounds.radius
                  ) else {
                continue
            }

            let winsIdentityTie = nearestEntity.map { entity < $0 } ?? true
            if distance < nearestDistance ||
                (distance == nearestDistance && winsIdentityTie) {
                nearestEntity = entity
                nearestDistance = distance
            }
        }

        return nearestEntity
    }

    private func hitDistance(
        rayOrigin: SIMD3<Double>,
        rayDirection: SIMD3<Double>,
        center: SIMD3<Double>,
        radius: Double
    ) -> Double? {
        let offset = rayOrigin - center
        let projectedOffset = simd_dot(offset, rayDirection)
        let discriminant = projectedOffset * projectedOffset
            - (simd_dot(offset, offset) - radius * radius)
        guard discriminant.isFinite, discriminant >= 0 else {
            return nil
        }

        let root = discriminant.squareRoot()
        let nearDistance = -projectedOffset - root
        if nearDistance >= 0 {
            return nearDistance
        }

        let farDistance = -projectedOffset + root
        return farDistance >= 0 ? farDistance : nil
    }
}
