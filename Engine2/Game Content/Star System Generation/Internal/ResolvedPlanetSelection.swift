/// Formation bodies selected for detailed planet output and the aggregated residual population.
///
/// V1 resolves bodies that grew to the calibrated solid-mass significance. If
/// none did, it retains the body with the greatest solid mass so every generated
/// system has one concrete primary body. The remaining composition and ancestry
/// stay in the ledger instead of being labeled as individually resolved planets.
nonisolated struct ResolvedPlanetSelection: Sendable {
    let embryos: [FormationEmbryo]
    let residualComposition: CelestialMassComposition
    let residualBodyCount: Int
    let residualProgenitorCount: Int
}
