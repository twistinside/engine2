/// Conservation and bounded-work ledger for one completed generation run.
///
/// Retained bodies, unaccreted solids, and explicit post-disk dynamical
/// destinations close every initial solid component. The residual-body fields
/// aggregate surviving formation bodies below the model's resolved-planet
/// threshold. Retained envelopes, residual gas, escaped atmosphere, dispersed
/// nebular gas, and dynamical destinations close the initial hydrogen-helium budget.
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
    let seededEmbryoCount: Int
    let formationMergerCount: Int
    let postDiskCollisionMergerCount: Int
}
