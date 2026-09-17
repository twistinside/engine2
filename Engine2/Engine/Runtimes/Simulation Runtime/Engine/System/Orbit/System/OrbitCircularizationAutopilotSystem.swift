/// Advances engaged circularization maneuvers with finite thrust and fuel.
///
/// Guidance retains the direction selected at engagement while recalculating
/// the live ideal target each tick. Autopilot authority suppresses manual
/// translation through its terminal tick and releases control after success or
/// any state that can no longer define or fund the maneuver.
struct OrbitCircularizationAutopilotSystem: System {
    let completionTolerance: Double

    init(completionTolerance: Double) {
        precondition(
            completionTolerance.isFinite && completionTolerance > 0,
            "Completion tolerance must be finite and positive."
        )
        self.completionTolerance = completionTolerance
    }

    mutating func update(world: inout World, deltaTime: Double) {
        guard deltaTime.isFinite, deltaTime > 0 else {
            return
        }

        let entities = world.components[OrbitCircularizationAutopilotComponent.self].entities
        for entity in entities {
            guard world.components[OrbitCircularizationAutopilotComponent.self][entity]?.isEngaged == true else {
                continue
            }
            suppressTranslation(for: entity, in: world)
            advanceManeuver(for: entity, in: world, deltaTime: deltaTime)
        }
    }

    private func advanceManeuver(
        for entity: EntityID,
        in world: World,
        deltaTime: Double
    ) {
        guard let estimate = world.orbitCircularizationEstimate(for: entity) else {
            disengage(entity, in: world)
            return
        }
        guard estimate.deltaV > completionTolerance else {
            disengage(entity, in: world)
            return
        }
        guard estimate.hasSufficientFuel,
              let propulsion = world.components[PropulsionComponent.self][entity],
              let fuel = world.components[FuelComponent.self][entity],
              let massComponent = world.components[MassComponent.self][entity],
              let motion = world.components[MotionComponent.self][entity] else {
            disengage(entity, in: world)
            return
        }

        let mass = massComponent.totalMass(
            fuel: fuel,
            cargo: world.components[CargoComponent.self][entity]
        )
        guard let burn = propulsion.burn(
            toward: estimate.deltaVelocity,
            mass: mass,
            availableFuel: fuel.remaining,
            deltaTime: deltaTime
        ) else {
            disengage(entity, in: world)
            return
        }

        let acceleration = motion.accumulator.acceleration + burn.acceleration
        let remainingFuel = max(0, fuel.remaining - burn.fuelUsed)
        guard acceleration.isFinite,
              remainingFuel.isFinite,
              remainingFuel <= fuel.capacity else {
            disengage(entity, in: world)
            return
        }

        world.components[MotionComponent.self].update(for: entity) { component in
            component.accumulator.acceleration = acceleration
        }
        world.components[FuelComponent.self].update(for: entity) { component in
            component.remaining = remainingFuel
        }
    }

    private func disengage(_ entity: EntityID, in world: World) {
        world.components[OrbitCircularizationAutopilotComponent.self].update(for: entity) { component in
            component = .idle
        }
    }

    private func suppressTranslation(for entity: EntityID, in world: World) {
        world.components[PlayerControlComponent.self].update(for: entity) { component in
            component.translation = .zero
        }
    }
}
