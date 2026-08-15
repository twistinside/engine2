import Foundation

/// Projects a finite secondary-atmosphere supply from one body's volatile reservoir.
///
/// The empirical cosmic shoreline acts as a survival boundary. Bodies on the
/// erosive side lose the complete supplied phase instead of retaining a trace.
nonisolated struct SecondaryAtmosphereResolver: Sendable {
    private static let cosmicShorelineThreshold = -0.25

    func atmosphereMassEarth(
        composition: CelestialMassComposition,
        massEarth: Double,
        solidRadiusEarth: Double,
        incidentFluxEarth: Double
    ) -> Double {
        let accessibleVolatiles = composition.water.earthMasses
            + composition.otherVolatiles.earthMasses
        let geologicSupply = massEarth / (massEarth + 0.3)
        let suppliedAtmosphereEarth = accessibleVolatiles * 0.0001 * geologicSupply
        guard survivesCosmicShoreline(
            massEarth: massEarth,
            solidRadiusEarth: solidRadiusEarth,
            incidentFluxEarth: incidentFluxEarth
        ) else {
            return 0
        }
        return suppliedAtmosphereEarth
    }

    private func survivesCosmicShoreline(
        massEarth: Double,
        solidRadiusEarth: Double,
        incidentFluxEarth: Double
    ) -> Bool {
        let escapeVelocityEarth = sqrt(max(massEarth / solidRadiusEarth, 1e-8))
        let shorelineIndex = 4 * log10(max(escapeVelocityEarth, 1e-5))
            - log10(max(incidentFluxEarth, 1e-6))
        return shorelineIndex >= Self.cosmicShorelineThreshold
    }
}
