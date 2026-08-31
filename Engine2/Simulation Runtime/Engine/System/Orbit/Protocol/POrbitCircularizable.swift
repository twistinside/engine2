/// Facade capability for a dynamic craft with live circularization guidance.
protocol POrbitCircularizable: PGravityAffected, PCollidable, PLiveMass, PPropelled, PFueled {
    var isOrbitCircularizationActive: Bool { get }
    var orbitCircularizationEstimate: OrbitCircularizationEstimate? { get }
}

extension POrbitCircularizable {
    var isOrbitCircularizationActive: Bool {
        guard let autopilot = world.orbitCircularizationAutopilotComponents[id] else {
            fatalError("There is no orbit circularization autopilot for the capable entity with ID: \(id)")
        }
        return autopilot.isEngaged
    }

    var orbitCircularizationEstimate: OrbitCircularizationEstimate? {
        world.orbitCircularizationEstimate(for: id)
    }
}
