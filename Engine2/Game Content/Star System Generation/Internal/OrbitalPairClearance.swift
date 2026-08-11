import Foundation

/// Mutual-Hill spacing and eccentric radial separation for one ordered orbital pair.
///
/// Both semimajor axes must use the same linear unit. The resulting radii and
/// separation use that unit, while mutual-Hill spacing remains dimensionless.
nonisolated struct OrbitalPairClearance: Sendable {
    let mutualHillRadius: Double
    let mutualHillSpacing: Double
    let radialSeparation: Double

    init(
        innerMass: AstronomicalMass,
        outerMass: AstronomicalMass,
        centralMass: AstronomicalMass,
        innerSemimajorAxis: Double,
        outerSemimajorAxis: Double,
        innerEccentricity: Double,
        outerEccentricity: Double
    ) {
        let combinedMassEarth = innerMass.earthMasses + outerMass.earthMasses
        let meanAxis = (innerSemimajorAxis + outerSemimajorAxis) / 2
        let mutualHillRadius = pow(
            combinedMassEarth / (3 * centralMass.earthMasses),
            1.0 / 3.0
        ) * meanAxis
        self.mutualHillRadius = mutualHillRadius
        mutualHillSpacing = (outerSemimajorAxis - innerSemimajorAxis) / mutualHillRadius
        radialSeparation = outerSemimajorAxis * (1 - outerEccentricity)
            - innerSemimajorAxis * (1 + innerEccentricity)
    }
}
