/// Conservation and bounded-work ledger for one completed generation run.
///
/// Current planets and moons plus `unaccretedSolidComposition` close each
/// initial solid component. Retained primordial envelopes plus escaped and
/// dispersed gas close the initial gas budget.
nonisolated struct StarSystemFormationLedger: Codable, Equatable, Sendable {
    let initialSolidMass: AstronomicalMass
    let retainedSolidMass: AstronomicalMass
    let unaccretedSolidMass: AstronomicalMass
    let unaccretedSolidComposition: CelestialMassComposition
    let initialGasMass: AstronomicalMass
    let retainedHydrogenHeliumMass: AstronomicalMass
    let escapedHydrogenHeliumMass: AstronomicalMass
    let dispersedGasMass: AstronomicalMass
    let seededEmbryoCount: Int
    let formationMergerCount: Int
    let stabilityMergerCount: Int
}
