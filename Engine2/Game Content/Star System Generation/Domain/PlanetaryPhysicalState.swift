/// Orthogonal derived classifications of one body's present physical state.
///
/// The generator retains these separate axes instead of forcing transition
/// bodies into one authored `PlanetKind`. Gameplay may later project its own
/// categories from the underlying facts.
nonisolated struct PlanetaryPhysicalState: Codable, Equatable, Sendable {
    let bulk: PlanetaryBulkRegime
    let visibleBoundary: PlanetaryVisibleBoundary
    let atmosphere: PlanetaryAtmosphereRegime
    let thermal: PlanetaryThermalRegime
    let water: PlanetaryWaterRegime
}
