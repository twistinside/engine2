/// Executes one all-or-nothing instantaneous circularization command.
///
/// The command is consumed even when current state cannot fund or define the
/// burn. A successful burn contributes one velocity impulse, consumes the
/// estimated propellant, and cancels translation input for the same tick.
struct SOrbitCircularization: PSystem {
    mutating func update(world: inout World, deltaTime _: Double) {
        guard let command = world.orbitCircularizationCommand else {
            return
        }
        world.orbitCircularizationCommand = nil

        guard let estimate = world.orbitCircularizationEstimate(for: command.entityID),
              estimate.hasSufficientFuel,
              let motion = world.motionComponents[command.entityID],
              let fuel = world.fuelComponents[command.entityID] else {
            return
        }

        let updatedImpulse = motion.accumulator.impulse + estimate.deltaVelocity
        let updatedFuel = fuel.remaining - estimate.requiredFuel
        guard updatedImpulse.isFinite,
              updatedFuel.isFinite,
              updatedFuel >= 0,
              updatedFuel <= fuel.capacity else {
            return
        }

        world.motionComponents.update(for: command.entityID) { component in
            component.accumulator.impulse = updatedImpulse
        }
        world.fuelComponents.update(for: command.entityID) { component in
            component.remaining = updatedFuel
        }
        world.playerControlComponents.update(for: command.entityID) { component in
            component.translation = .zero
        }
    }
}
