/// Standard gravitational parameter stored in cubic meters per second squared.
///
/// The pinned Newtonian constant is part of the celestial-dynamics model
/// version. Two-body rails include both participating masses; test-particle
/// trajectories pass zero as the orbiting mass.
nonisolated struct GravitationalParameter: Codable, Equatable, Hashable, Sendable {
    static let newtonianGravitationalConstantCubicMetersPerKilogramSecondSquared = 6.67430e-11

    let cubicMetersPerSecondSquared: Double

    init(cubicMetersPerSecondSquared: Double) {
        precondition(
            cubicMetersPerSecondSquared.isFinite && cubicMetersPerSecondSquared > 0,
            "A gravitational parameter must be positive and finite."
        )
        self.cubicMetersPerSecondSquared = cubicMetersPerSecondSquared
    }

    init(primaryMass: AstronomicalMass, orbitingMass: AstronomicalMass) {
        precondition(primaryMass.kilograms > 0, "A gravitational primary must have positive mass.")
        self.init(
            cubicMetersPerSecondSquared:
                Self.newtonianGravitationalConstantCubicMetersPerKilogramSecondSquared
                    * (primaryMass.kilograms + orbitingMass.kilograms)
        )
    }
}
