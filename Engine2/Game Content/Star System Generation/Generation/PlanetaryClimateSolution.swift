/// Converged temperatures and albedo for one zero-dimensional climate solve.
nonisolated struct PlanetaryClimateSolution: Sendable {
    let equilibriumTemperatureKelvin: Double
    let visibleBoundaryTemperatureKelvin: Double
    let bondAlbedo: Double
}
