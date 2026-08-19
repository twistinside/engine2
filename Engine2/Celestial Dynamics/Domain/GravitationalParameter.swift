/// Standard gravitational parameter stored in cubic meters per second squared.
///
/// The pinned Newtonian constant is part of the celestial-dynamics model
/// version. Two-body rails include both participating masses; test-particle
/// trajectories pass zero as the orbiting mass.
nonisolated struct GravitationalParameter: Equatable, Hashable, Sendable {
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
        precondition(
            primaryMass.kilograms.isFinite && primaryMass.kilograms > 0,
            "A gravitational primary must have positive finite mass."
        )
        precondition(
            orbitingMass.kilograms.isFinite && orbitingMass.kilograms >= 0,
            "An orbiting body must have finite nonnegative mass."
        )
        self.init(
            cubicMetersPerSecondSquared:
                Self.newtonianGravitationalConstantCubicMetersPerKilogramSecondSquared
                    * (primaryMass.kilograms + orbitingMass.kilograms)
        )
    }
}

extension GravitationalParameter: Codable {
    private enum CodingKeys: String, CodingKey {
        case cubicMetersPerSecondSquared
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let value = try container.decode(Double.self, forKey: .cubicMetersPerSecondSquared)
        guard value.isFinite, value > 0 else {
            throw DecodingError.dataCorruptedError(
                forKey: .cubicMetersPerSecondSquared,
                in: container,
                debugDescription: "A gravitational parameter must be positive and finite."
            )
        }
        self.init(cubicMetersPerSecondSquared: value)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(cubicMetersPerSecondSquared, forKey: .cubicMetersPerSecondSquared)
    }
}
