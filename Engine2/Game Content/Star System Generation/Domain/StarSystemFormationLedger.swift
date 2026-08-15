/// Conservation and bounded-work ledger for one completed generation run.
///
/// Retained bodies, unaccreted solids, and explicit post-disk dynamical
/// destinations close every initial solid component. The residual-body fields
/// aggregate survivors omitted by resolved-planet significance or multiplicity.
/// Retained envelopes, residual gas, escaped atmosphere, dispersed nebular gas,
/// and dynamical destinations close the initial hydrogen-helium budget.
nonisolated struct StarSystemFormationLedger: Codable, Equatable, Sendable {
    let initialSolidMass: AstronomicalMass
    let retainedSolidMass: AstronomicalMass
    let unaccretedSolidMass: AstronomicalMass
    let unaccretedSolidComposition: CelestialMassComposition
    let initialGasMass: AstronomicalMass
    let retainedHydrogenHeliumMass: AstronomicalMass
    let escapedHydrogenHeliumMass: AstronomicalMass
    let dispersedGasMass: AstronomicalMass
    let dynamicalLosses: StarSystemDynamicalLossLedger
    let residualBodyComposition: CelestialMassComposition
    let residualBodyCount: Int
    let residualProgenitorCount: Int
    let resolvedPlanetCapacity: Int
    let seededEmbryoCount: Int
    let formationMergerCount: Int
    let postDiskCollisionMergerCount: Int
}
