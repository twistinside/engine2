import Foundation

/// Mutable planetary precursor evolved during the gas-disk and clearing phases.
nonisolated struct FormationEmbryo: Sendable {
    let id: GeneratedBodyID
    var semiMajorAxisAU: Double
    var eccentricity: Double
    var inclinationDegrees: Double
    var composition: CelestialMassComposition
    var progenitorCount: Int

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

    /// Returns one collision remnant that conserves composition and circular-orbit angular momentum.
    func merging(with other: FormationEmbryo) -> FormationEmbryo {
        let firstMass = composition.totalMass.earthMasses
        let secondMass = other.composition.totalMass.earthMasses
        let totalMass = firstMass + secondMass
        let angularMomentumRadius = (
            firstMass * sqrt(semiMajorAxisAU)
                + secondMass * sqrt(other.semiMajorAxisAU)
        ) / totalMass
        return FormationEmbryo(
            id: min(id, other.id),
            semiMajorAxisAU: angularMomentumRadius * angularMomentumRadius,
            eccentricity: 0,
            inclinationDegrees: 0,
            composition: composition.adding(other.composition),
            progenitorCount: progenitorCount + other.progenitorCount
        )
    }
}
