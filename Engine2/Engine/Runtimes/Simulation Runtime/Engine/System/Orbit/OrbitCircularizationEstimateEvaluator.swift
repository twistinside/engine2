import Foundation
import simd

/// Evaluates live planar circularization guidance against authoritative ECS rows.
///
/// Invalid or incomplete state and contact with the designated primary have no
/// estimate. An engaged autopilot retains its latched direction. Otherwise,
/// both directions remain candidates and equal burns select counterclockwise.
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
              let mass = world.massComponents[entityID] else {
            return nil
        }
        let liveMass = mass.totalMass(
            fuel: fuel,
            cargo: world.cargoComponents[entityID]
        )
        guard liveMass.isFinite,
              liveMass > 0 else {
            return nil
        }
        let finalMass = liveMass - fuel.remaining
        guard finalMass.isFinite, finalMass > 0 else {
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
        let radiusCubed = radius * radius * radius
        let localOrbitalPeriod = 2 * Double.pi * sqrt(
            radiusCubed / gravitySource.gravitationalParameter
        )
        guard radiusCubed.isFinite,
              radiusCubed > 0,
              localOrbitalPeriod.isFinite,
              localOrbitalPeriod > 0 else {
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

        let direction: OrbitCircularizationAutopilotComponent.Direction
        let targetVelocity: SIMD3<Double>
        let deltaVelocity: SIMD3<Double>
        let deltaV: Double
        let latchedDirection = world.orbitCircularizationAutopilotComponents[entityID]?.direction
        if latchedDirection == .counterclockwise
            || (latchedDirection == nil && counterclockwiseDeltaV <= clockwiseDeltaV) {
            direction = .counterclockwise
            targetVelocity = counterclockwiseTarget
            deltaVelocity = counterclockwiseDelta
            deltaV = counterclockwiseDeltaV
        } else {
            direction = .clockwise
            targetVelocity = clockwiseTarget
            deltaVelocity = clockwiseDelta
            deltaV = clockwiseDeltaV
        }

        let availableDeltaV = propulsion.exhaustVelocity * log(liveMass / finalMass)
        let requiredFuel = -liveMass * expm1(-deltaV / propulsion.exhaustVelocity)
        let deltaVMargin = availableDeltaV - deltaV
        let minimumBurnDuration = requiredFuel * propulsion.exhaustVelocity
            / propulsion.maximumThrust
        guard availableDeltaV.isFinite,
              availableDeltaV >= 0,
              requiredFuel.isFinite,
              requiredFuel >= 0,
              deltaVMargin.isFinite,
              minimumBurnDuration.isFinite,
              minimumBurnDuration >= 0 else {
            return nil
        }

        return OrbitCircularizationEstimate(
            availableDeltaV: availableDeltaV,
            deltaVelocity: deltaVelocity,
            deltaV: deltaV,
            deltaVMargin: deltaVMargin,
            direction: direction,
            hasSufficientFuel: requiredFuel <= fuel.remaining,
            localOrbitalPeriod: localOrbitalPeriod,
            minimumBurnDuration: minimumBurnDuration,
            requiredFuel: requiredFuel,
            targetVelocity: targetVelocity
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
