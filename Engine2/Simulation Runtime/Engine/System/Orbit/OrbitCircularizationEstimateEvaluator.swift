import Foundation
import simd

/// Evaluates an instantaneous planar circularization against live ECS rows.
///
/// Invalid or incomplete state and contact with the designated primary have no
/// estimate. Both circular directions remain candidates; equal burns select
/// counterclockwise motion deterministically.
struct OrbitCircularizationEstimateEvaluator {
    func estimate(for entityID: EntityID, in world: World) -> OrbitCircularizationEstimate? {
        guard let orbitPrimary = world.orbitPrimaryComponents[entityID],
              orbitPrimary.primaryEntityID != entityID,
              let entityPosition = world.positionComponents[entityID]?.position,
              let primaryPosition = world.positionComponents[orbitPrimary.primaryEntityID]?.position,
              let entityMotion = world.motionComponents[entityID],
              let gravitySource = world.gravitySourceComponents[orbitPrimary.primaryEntityID],
              let entityBody = world.collisionBodyComponents[entityID],
              let primaryBody = world.collisionBodyComponents[orbitPrimary.primaryEntityID],
              let propulsion = world.propulsionComponents[entityID],
              let fuel = world.fuelComponents[entityID],
              let liveMass = world.liveMass(for: entityID),
              liveMass.isFinite,
              liveMass > 0 else {
            return nil
        }

        let radialOffset = SIMD2<Double>(
            entityPosition.x - primaryPosition.x,
            entityPosition.y - primaryPosition.y
        )
        let radius = simd_length(radialOffset)
        let contactRadius = entityBody.radius + primaryBody.radius
        guard radialOffset.isFinite,
              radius.isFinite,
              radius > contactRadius,
              contactRadius.isFinite,
              contactRadius > 0 else {
            return nil
        }

        let currentVelocity = entityMotion.velocity + entityMotion.accumulator.impulse
        let primaryVelocity = instantaneousVelocity(of: orbitPrimary.primaryEntityID, in: world)
        let circularSpeed = sqrt(gravitySource.gravitationalParameter / radius)
        guard currentVelocity.isFinite,
              primaryVelocity.isFinite,
              circularSpeed.isFinite,
              circularSpeed >= 0 else {
            return nil
        }

        let radialDirection = radialOffset / radius
        let counterclockwiseTangent = SIMD2<Double>(-radialDirection.y, radialDirection.x)
        let counterclockwiseTarget = primaryVelocity + SIMD3<Double>(
            counterclockwiseTangent.x * circularSpeed,
            counterclockwiseTangent.y * circularSpeed,
            0
        )
        let clockwiseTarget = primaryVelocity - SIMD3<Double>(
            counterclockwiseTangent.x * circularSpeed,
            counterclockwiseTangent.y * circularSpeed,
            0
        )
        let counterclockwiseDelta = counterclockwiseTarget - currentVelocity
        let clockwiseDelta = clockwiseTarget - currentVelocity
        let counterclockwiseDeltaV = simd_length(counterclockwiseDelta)
        let clockwiseDeltaV = simd_length(clockwiseDelta)
        guard counterclockwiseTarget.isFinite,
              clockwiseTarget.isFinite,
              counterclockwiseDelta.isFinite,
              clockwiseDelta.isFinite,
              counterclockwiseDeltaV.isFinite,
              clockwiseDeltaV.isFinite else {
            return nil
        }

        let targetVelocity: SIMD3<Double>
        let deltaVelocity: SIMD3<Double>
        let deltaV: Double
        if counterclockwiseDeltaV <= clockwiseDeltaV {
            targetVelocity = counterclockwiseTarget
            deltaVelocity = counterclockwiseDelta
            deltaV = counterclockwiseDeltaV
        } else {
            targetVelocity = clockwiseTarget
            deltaVelocity = clockwiseDelta
            deltaV = clockwiseDeltaV
        }

        let requiredFuel = -liveMass * expm1(-deltaV / propulsion.exhaustVelocity)
        guard requiredFuel.isFinite,
              requiredFuel >= 0 else {
            return nil
        }

        return OrbitCircularizationEstimate(
            deltaVelocity: deltaVelocity,
            targetVelocity: targetVelocity,
            deltaV: deltaV,
            requiredFuel: requiredFuel,
            hasSufficientFuel: requiredFuel <= fuel.remaining
        )
    }

    private func instantaneousVelocity(of entityID: EntityID, in world: World) -> SIMD3<Double> {
        if let rail = world.orbitalRailComponents[entityID] {
            return rail.velocity
        }
        if let motion = world.motionComponents[entityID] {
            return motion.velocity + motion.accumulator.impulse
        }
        return .zero
    }
}
