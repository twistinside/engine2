/// Facade capability for a dynamic craft with live circularization guidance.
protocol OrbitCircularizable: GravityAffected, Collidable, LiveMass, Propelled, Fueled {
    var isOrbitCircularizationActive: Bool { get }
    var orbitCircularizationEstimate: OrbitCircularizationEstimate? { get }
}

extension OrbitCircularizable {
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
