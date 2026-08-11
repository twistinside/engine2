/// Conserved satellite material removed from a parent before present-day resolution.
nonisolated struct FormationMoonSeed: Sendable {
    let id: GeneratedBodyID
    let origin: MoonFormationOrigin
    let composition: CelestialMassComposition
    let normalizedOrbitIndex: Double
}
