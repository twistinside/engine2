/// Present-day body result shared by planet and moon construction phases.
nonisolated struct EvolvedPlanetaryBody: Sendable {
    let composition: CelestialMassComposition
    let radius: AstronomicalDistance
    let environment: PlanetaryEnvironment
    let physicalState: PlanetaryPhysicalState
    let escapedHydrogenHeliumMass: AstronomicalMass
}
