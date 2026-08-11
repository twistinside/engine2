/// Sampled protoplanetary-disk properties retained as system provenance.
///
/// The transient annulus ledger is consumed during generation. This immutable
/// summary preserves its normalization, spatial extent, condensation boundary,
/// lifetime, and initial conserved reservoirs.
nonisolated struct GeneratedProtoplanetaryDisk: Codable, Equatable, Sendable {
    let initialGasMass: AstronomicalMass
    let initialSolidMass: AstronomicalMass
    let initialSolidComposition: CelestialMassComposition
    let lifetime: AstronomicalDuration
    let characteristicRadius: AstronomicalDistance
    let surfaceDensityExponent: Double
    let innerEdge: AstronomicalDistance
    let outerEdge: AstronomicalDistance
    let waterSnowLine: AstronomicalDistance
    let annulusCount: Int
}
