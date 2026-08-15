import Foundation

/// Mutable planetary precursor evolved during the gas-disk and clearing phases.
nonisolated struct FormationEmbryo: Sendable {
    let id: GeneratedBodyID
    var semiMajorAxisAU: Double
    var eccentricity: Double
    var inclinationDegrees: Double
    var composition: CelestialMassComposition
    var progenitorCount: Int

    var estimatedRadiusEarthRadii: Double {
        let solidMassEarth = max(composition.solidMass.earthMasses, 1e-6)
        let coreRadiusEarth = pow(solidMassEarth, 0.27)
        let envelopeFraction = composition.hydrogenHeliumMassFraction
        guard envelopeFraction > 1e-6 else {
            return coreRadiusEarth
        }
        if composition.totalMass.earthMasses >= 50 || envelopeFraction >= 0.5 {
            return min(12, max(coreRadiusEarth, 8 + 4 * min(envelopeFraction, 1)))
        }
        return coreRadiusEarth * (1 + min(2.5, 4 * sqrt(envelopeFraction)))
    }

    func orbitalClearance(
        to outer: FormationEmbryo,
        around centralMass: AstronomicalMass
    ) -> OrbitalPairClearance {
        OrbitalPairClearance(
            innerMass: composition.totalMass,
            outerMass: outer.composition.totalMass,
            centralMass: centralMass,
            innerSemimajorAxis: semiMajorAxisAU,
            outerSemimajorAxis: outer.semiMajorAxisAU,
            innerEccentricity: eccentricity,
            outerEccentricity: outer.eccentricity
        )
    }

    /// Returns a remnant and debris that together conserve every composition component.
    func colliding(
        with other: FormationEmbryo,
        retainedSolidFraction: Double,
        retainedHydrogenHeliumFraction: Double
    ) -> (remnant: FormationEmbryo, debris: CelestialMassComposition) {
        precondition(
            retainedSolidFraction.isFinite && (0...1).contains(retainedSolidFraction),
            "Collision solid retention must be a finite unit factor."
        )
        precondition(
            retainedHydrogenHeliumFraction.isFinite && (0...1).contains(retainedHydrogenHeliumFraction),
            "Collision gas retention must be a finite unit factor."
        )
        let firstMass = composition.totalMass.earthMasses
        let secondMass = other.composition.totalMass.earthMasses
        let totalMass = firstMass + secondMass
        let angularMomentumRadius = (
            firstMass * sqrt(semiMajorAxisAU)
                + secondMass * sqrt(other.semiMajorAxisAU)
        ) / totalMass
        let combinedComposition = composition.adding(other.composition)
        let remnantComposition = CelestialMassComposition(
            iron: AstronomicalMass(
                earthMasses: combinedComposition.iron.earthMasses * retainedSolidFraction
            ),
            silicate: AstronomicalMass(
                earthMasses: combinedComposition.silicate.earthMasses * retainedSolidFraction
            ),
            water: AstronomicalMass(
                earthMasses: combinedComposition.water.earthMasses * retainedSolidFraction
            ),
            otherVolatiles: AstronomicalMass(
                earthMasses: combinedComposition.otherVolatiles.earthMasses * retainedSolidFraction
            ),
            hydrogenHelium: AstronomicalMass(
                earthMasses: combinedComposition.hydrogenHelium.earthMasses
                    * retainedHydrogenHeliumFraction
            )
        )
        let debrisComposition = CelestialMassComposition(
            iron: AstronomicalMass(
                earthMasses: combinedComposition.iron.earthMasses * (1 - retainedSolidFraction)
            ),
            silicate: AstronomicalMass(
                earthMasses: combinedComposition.silicate.earthMasses * (1 - retainedSolidFraction)
            ),
            water: AstronomicalMass(
                earthMasses: combinedComposition.water.earthMasses * (1 - retainedSolidFraction)
            ),
            otherVolatiles: AstronomicalMass(
                earthMasses: combinedComposition.otherVolatiles.earthMasses * (1 - retainedSolidFraction)
            ),
            hydrogenHelium: AstronomicalMass(
                earthMasses: combinedComposition.hydrogenHelium.earthMasses
                    * (1 - retainedHydrogenHeliumFraction)
            )
        )
        let remnant = FormationEmbryo(
            id: min(id, other.id),
            semiMajorAxisAU: angularMomentumRadius * angularMomentumRadius,
            eccentricity: 0,
            inclinationDegrees: 0,
            composition: remnantComposition,
            progenitorCount: progenitorCount + other.progenitorCount
        )
        return (remnant, debrisComposition)
    }
}
