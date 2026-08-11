/// Atmosphere and pressure facts needed to solve one visible-boundary climate.
///
/// The value distinguishes pressure at an exposed solid surface from the
/// pressure column used at an opaque visible boundary.
nonisolated struct PlanetaryAtmosphericBoundary: Sendable {
    let atmosphereMassEarth: Double
    let exposedSurfacePressureBars: Double
    let climatePressureBars: Double
    let opticalDepth: Double
    let isOpaque: Bool
}
