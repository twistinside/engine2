import simd

/// Steers controlled planar velocity toward a target while consuming fuel.
///
/// Maximum force and current live mass bound acceleration. Fuel consumption is
/// the applied impulse divided by exhaust velocity, so a partially fueled burn
/// produces only the impulse the remaining propellant can fund.
struct SFlightControl: PSystem {
    let responseTime: Double
    let targetSpeed: Double

    init(targetSpeed: Double, responseTime: Double) {
        precondition(targetSpeed.isFinite && targetSpeed > 0, "Target speed must be finite and positive.")
        precondition(responseTime.isFinite && responseTime > 0, "Velocity response time must be finite and positive.")
        self.targetSpeed = targetSpeed
        self.responseTime = responseTime
    }

    mutating func update(world: inout World, deltaTime: Double) {
        guard deltaTime.isFinite, deltaTime > 0 else {
            return
        }

        let entities = world.playerControlComponents.entities
        for entity in entities {
            applyControl(to: entity, in: world, deltaTime: deltaTime)
        }
    }

    private func applyControl(to entity: EntityID, in world: World, deltaTime: Double) {
        guard let control = world.playerControlComponents[entity],
              let propulsion = world.propulsionComponents[entity],
              let fuel = world.fuelComponents[entity],
              let motion = world.motionComponents[entity],
              let massComponent = world.massComponents[entity],
              fuel.remaining > 0 else {
            return
        }
        let mass = massComponent.totalMass(
            fuel: fuel,
            cargo: world.cargoComponents[entity]
        )
        guard mass.isFinite, mass > 0 else {
            return
        }

        let inputMagnitude = simd_length(control.translation)
        guard inputMagnitude.isFinite, inputMagnitude > 0 else {
            return
        }
        let boundedInputMagnitude = min(inputMagnitude, 1)
        let cameraRight = world.camera.rotation.act(SIMD3<Float>(1, 0, 0))
        let cameraUp = world.camera.rotation.act(SIMD3<Float>(0, 1, 0))
        guard let planarRight = normalizedPlanarDirection(
            cameraRight,
            requiredBy: control.translation.x
        ),
        let planarUp = normalizedPlanarDirection(
            cameraUp,
            requiredBy: control.translation.y
        ) else {
            return
        }
        let worldDirection = planarRight * control.translation.x
            + planarUp * control.translation.y
        let worldDirectionMagnitude = simd_length(worldDirection)
        guard worldDirection.isFinite,
              worldDirectionMagnitude.isFinite,
              worldDirectionMagnitude > 0 else {
            return
        }
        let targetVelocity = worldDirection / worldDirectionMagnitude * (targetSpeed * boundedInputMagnitude)
        let velocityError = targetVelocity - SIMD2<Double>(motion.velocity.x, motion.velocity.y)
        let requestedAcceleration = velocityError / responseTime
        let requestedForce = requestedAcceleration * mass
        let requestedForceMagnitude = simd_length(requestedForce)
        guard requestedForceMagnitude.isFinite, requestedForceMagnitude > 0 else {
            return
        }

        let appliedForceMagnitude = min(requestedForceMagnitude, propulsion.maximumThrust)
        let requestedImpulse = appliedForceMagnitude * deltaTime
        let availableImpulse = fuel.remaining * propulsion.exhaustVelocity
        let appliedImpulse = min(requestedImpulse, availableImpulse)
        guard appliedImpulse.isFinite, appliedImpulse > 0 else {
            return
        }

        let forceDirection = requestedForce / requestedForceMagnitude
        let appliedAcceleration2D = forceDirection * (appliedImpulse / deltaTime / mass)
        let fuelUsed = min(fuel.remaining, appliedImpulse / propulsion.exhaustVelocity)

        world.motionComponents.update(for: entity) { component in
            component.accumulator.acceleration += SIMD3<Double>(
                appliedAcceleration2D.x,
                appliedAcceleration2D.y,
                0
            )
        }
        world.fuelComponents.update(for: entity) { component in
            component.remaining -= fuelUsed
        }
    }

    private func normalizedPlanarDirection(
        _ direction: SIMD3<Float>,
        requiredBy input: Double
    ) -> SIMD2<Double>? {
        guard input != 0 else {
            return .zero
        }

        let candidate = SIMD2<Double>(Double(direction.x), Double(direction.y))
        let length = simd_length(candidate)
        guard candidate.isFinite, length.isFinite, length > 0 else {
            return nil
        }
        return candidate / length
    }
}
