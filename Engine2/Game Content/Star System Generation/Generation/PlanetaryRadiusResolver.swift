import Foundation

/// Resolves the solid and visible radii used by atmosphere evolution and climate.
///
/// The bounded relations cover the generator's calibrated rocky, volatile-rich,
/// envelope-bearing, and giant-body regimes. They are not interior structure solvers.
nonisolated struct PlanetaryRadiusResolver: Sendable {
    func resolveVisibleRadiusEarth(
        composition: CelestialMassComposition,
        incidentFluxEarth: Double,
        ageGigayears: Double
    ) -> Double {
        let solidRadius = resolveSolidRadiusEarth(composition: composition)
        let totalMass = composition.totalMass.earthMasses
        let envelopeFraction = composition.hydrogenHeliumMassFraction
        guard envelopeFraction > 1e-5 else {
            return max(solidRadius, 0.03)
        }
        if envelopeFraction >= 0.5 && totalMass >= 30 {
            let giantRadius = min(
                14,
                max(8, 10.5 + 0.6 * log10(max(totalMass / 100, 0.1)))
            )
            return max(solidRadius, giantRadius)
        }
        let envelopeInflation = 2.2
            * pow(max(envelopeFraction / 0.05, 1e-4), 0.25)
            * pow(max(totalMass / 5, 0.1), -0.10)
            * pow(max(incidentFluxEarth, 0.01), 0.04)
            * pow(max(ageGigayears / 5, 0.02), -0.08)
        return max(solidRadius, min(10, solidRadius + envelopeInflation))
    }

    func resolveSolidRadiusEarth(
        composition: CelestialMassComposition
    ) -> Double {
        let solidMass = max(composition.solidMass.earthMasses, 1e-8)
        let waterFraction = composition.waterMassFraction
        let otherVolatileFraction = composition.otherVolatiles.earthMasses / solidMass
        return max(
            0.03,
            pow(solidMass, 0.27)
                * (1 + 0.25 * waterFraction + 0.10 * otherVolatileFraction)
        )
    }
}
