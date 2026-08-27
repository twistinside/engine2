/// Read-only facade capability for live instantaneous circularization estimates.
protocol POrbitCircularizable: Entity {
    var orbitCircularizationEstimate: OrbitCircularizationEstimate? { get }
}

extension POrbitCircularizable {
    var orbitCircularizationEstimate: OrbitCircularizationEstimate? {
        world.orbitCircularizationEstimate(for: id)
    }
}
