/// Conserved component masses of one planet, moon, embryo, or disk withdrawal.
///
/// Water and other volatiles include condensed, interior, and atmospheric
/// reservoirs. `hydrogenHelium` is tracked separately because the primordial
/// envelope follows different accretion and escape rules.
nonisolated struct CelestialMassComposition: Codable, Equatable, Sendable {
    static let zero = CelestialMassComposition(
        iron: .zero,
        silicate: .zero,
        water: .zero,
        otherVolatiles: .zero,
        hydrogenHelium: .zero
    )

    let iron: AstronomicalMass
    let silicate: AstronomicalMass
    let water: AstronomicalMass
    let otherVolatiles: AstronomicalMass
    let hydrogenHelium: AstronomicalMass

    var solidMass: AstronomicalMass {
        AstronomicalMass(
            earthMasses: iron.earthMasses
                + silicate.earthMasses
                + water.earthMasses
                + otherVolatiles.earthMasses
        )
    }

    var totalMass: AstronomicalMass {
        AstronomicalMass(earthMasses: solidMass.earthMasses + hydrogenHelium.earthMasses)
    }

    var waterMassFraction: Double {
        guard solidMass.earthMasses > 0 else {
            return 0
        }
        return water.earthMasses / solidMass.earthMasses
    }

    var hydrogenHeliumMassFraction: Double {
        guard totalMass.earthMasses > 0 else {
            return 0
        }
        return hydrogenHelium.earthMasses / totalMass.earthMasses
    }

    func adding(_ other: CelestialMassComposition) -> CelestialMassComposition {
        CelestialMassComposition(
            iron: AstronomicalMass(earthMasses: iron.earthMasses + other.iron.earthMasses),
            silicate: AstronomicalMass(earthMasses: silicate.earthMasses + other.silicate.earthMasses),
            water: AstronomicalMass(earthMasses: water.earthMasses + other.water.earthMasses),
            otherVolatiles: AstronomicalMass(
                earthMasses: otherVolatiles.earthMasses + other.otherVolatiles.earthMasses
            ),
            hydrogenHelium: AstronomicalMass(
                earthMasses: hydrogenHelium.earthMasses + other.hydrogenHelium.earthMasses
            )
        )
    }

    func scaled(by factor: Double) -> CelestialMassComposition {
        precondition(factor.isFinite && factor >= 0, "A composition scale must be finite and nonnegative.")
        return CelestialMassComposition(
            iron: AstronomicalMass(earthMasses: iron.earthMasses * factor),
            silicate: AstronomicalMass(earthMasses: silicate.earthMasses * factor),
            water: AstronomicalMass(earthMasses: water.earthMasses * factor),
            otherVolatiles: AstronomicalMass(earthMasses: otherVolatiles.earthMasses * factor),
            hydrogenHelium: AstronomicalMass(earthMasses: hydrogenHelium.earthMasses * factor)
        )
    }

    func replacingHydrogenHelium(with mass: AstronomicalMass) -> CelestialMassComposition {
        CelestialMassComposition(
            iron: iron,
            silicate: silicate,
            water: water,
            otherVolatiles: otherVolatiles,
            hydrogenHelium: mass
        )
    }
}
