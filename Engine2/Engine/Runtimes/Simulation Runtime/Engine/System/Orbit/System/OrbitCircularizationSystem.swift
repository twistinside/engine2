/// Consumes one command and engages persistent circularization authority.
///
/// The command is consumed even when current state cannot fund or define a
/// maneuver. Repeated commands do not change an engaged maneuver's direction.
struct OrbitCircularizationSystem: System {
    mutating func update(world: inout World, deltaTime _: Double) {
        guard let command = world.orbitCircularizationCommand else {
            return
        }
        world.orbitCircularizationCommand = nil

        guard let autopilot = world.orbitCircularizationAutopilotComponents[command.entityID] else {
            return
        }
        if autopilot.isEngaged {
            suppressTranslation(for: command.entityID, in: world)
            return
        }

        guard let estimate = world.orbitCircularizationEstimate(for: command.entityID),
              estimate.hasSufficientFuel else {
            return
        }

        world.orbitCircularizationAutopilotComponents.update(for: command.entityID) { component in
            component = .engaged(direction: estimate.direction)
        }
        suppressTranslation(for: command.entityID, in: world)
    }

    private func suppressTranslation(for entity: EntityID, in world: World) {
        world.playerControlComponents.update(for: entity) { component in
            component.translation = .zero
        }
    }
}
