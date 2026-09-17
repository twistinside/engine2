import simd

/// Evaluates relative planar swept-sphere geometry without selecting a gameplay response.
///
/// Both paths are clipped to their shared lifetime interval. Canonical pair identity and normal
/// orientation let any participant consume the same contact, including after an earlier bounce
/// changes an endpoint and requires a new geometric query.
struct CollisionEvaluator {
    func contact(between first: CollisionSweep, and second: CollisionSweep) -> CollisionContact? {
        guard first.entityID != second.entityID else {
            return nil
        }
        let travelFraction = min(first.travelFraction, second.travelFraction)
        let offset = first.previousPosition - second.previousPosition
        let relativePath = (
            (first.position - first.previousPosition) - (second.position - second.previousPosition)
        ) * travelFraction
        let radius = first.radius + second.radius
        guard travelFraction.isFinite, travelFraction > 0,
              offset.isFinite, relativePath.isFinite, radius.isFinite else {
            return nil
        }

        let distanceFromSurface = simd_length_squared(offset) - radius * radius
        let fraction: Double
        if distanceFromSurface <= 0 {
            fraction = 0
        } else {
            let pathLengthSquared = simd_length_squared(relativePath)
            guard pathLengthSquared.isFinite, pathLengthSquared > 0 else {
                return nil
            }
            let projectedOffset = 2 * simd_dot(offset, relativePath)
            let discriminant = projectedOffset * projectedOffset - 4 * pathLengthSquared * distanceFromSurface
            guard discriminant.isFinite, discriminant >= 0 else {
                return nil
            }
            let nearFraction = (-projectedOffset - discriminant.squareRoot()) / (2 * pathLengthSquared)
            guard nearFraction >= 0, nearFraction <= 1 else {
                return nil
            }
            fraction = nearFraction
        }

        let impactOffset = offset + relativePath * fraction
        let impactDistance = simd_length(impactOffset)
        let normal: SIMD2<Double>
        if impactDistance.isFinite, impactDistance > 0 {
            normal = impactOffset / impactDistance
        } else {
            let pathLength = simd_length(relativePath)
            if pathLength.isFinite, pathLength > 0 {
                normal = -relativePath / pathLength
            } else {
                normal = first.entityID < second.entityID ? SIMD2<Double>(1, 0) : SIMD2<Double>(-1, 0)
            }
        }

        let isCanonicalOrder = first.entityID < second.entityID
        return CollisionContact(
            firstEntityID: isCanonicalOrder ? first.entityID : second.entityID,
            secondEntityID: isCanonicalOrder ? second.entityID : first.entityID,
            tickFraction: fraction * travelFraction,
            normal: isCanonicalOrder ? normal : -normal
        )
    }
}
