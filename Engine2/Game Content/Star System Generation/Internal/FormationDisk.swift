/// Mutable annular disk plus the immutable summary retained in generated output.
nonisolated struct FormationDisk: Sendable {
    let summary: GeneratedProtoplanetaryDisk
    var annuli: [FormationAnnulus]
    var dispersedGasMassEarth: Double

    /// Returns collision solids to the nearest annulus and records stripped nebular gas as dispersed.
    mutating func returnCollisionDebris(
        _ composition: CelestialMassComposition,
        near radiusAU: Double
    ) {
        let nearestAnnulus = annuli.indices.min { first, second in
            abs(annuli[first].centerRadiusAU - radiusAU)
                < abs(annuli[second].centerRadiusAU - radiusAU)
        }
        guard let nearestAnnulus else {
            preconditionFailure("A formation disk must retain at least one annulus.")
        }
        let solidDebris = CelestialMassComposition(
            iron: composition.iron,
            silicate: composition.silicate,
            water: composition.water,
            otherVolatiles: composition.otherVolatiles,
            hydrogenHelium: .zero
        )
        annuli[nearestAnnulus].solidComposition = annuli[nearestAnnulus].solidComposition.adding(solidDebris)
        dispersedGasMassEarth += composition.hydrogenHelium.earthMasses
    }
}
