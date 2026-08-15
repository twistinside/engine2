/// Resolved stable protoplanetary-disk summary retained as system provenance.
///
/// The transient annulus ledger is consumed during generation. This immutable
/// summary preserves its correlated shape, spatial extent, condensation boundary,
/// lifetime, and conserved reservoirs represented between its stored edges.
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
