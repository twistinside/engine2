/// Present-day environmental facts resolved from the star, orbit, mass, and composition.
///
/// This is a coarse zero-dimensional climate result. It is physical input for
/// later gameplay and presentation layers, not a claim of spatial weather or
/// detailed atmospheric chemistry.
nonisolated struct PlanetaryEnvironment: Codable, Equatable, Sendable {
    /// Orbit-averaged bolometric flux relative to modern Earth.
    let incidentFluxEarth: Double

    let equilibriumTemperature: ThermodynamicTemperature
    let visibleBoundaryTemperature: ThermodynamicTemperature
    /// Total resolved atmosphere phase mass. Exact zero denotes complete loss;
    /// every positive mass remains atmospheric even when its pressure is tiny.
    let atmosphereMass: AstronomicalMass

    /// Estimated pressure on an exposed solid boundary, or `nil` when a deep
    /// envelope makes the solid boundary inaccessible to the V1 climate model.
    let surfacePressure: SurfacePressure?

    /// Bond albedo in the closed `0...1` interval.
    let bondAlbedo: Double

    /// Estimated fraction of the solid boundary covered by stable liquid water.
    let liquidWaterCoverage: Double

    /// Estimated fraction of the solid boundary covered by water ice.
    let waterIceCoverage: Double

    init(
        incidentFluxEarth: Double,
        equilibriumTemperature: ThermodynamicTemperature,
        visibleBoundaryTemperature: ThermodynamicTemperature,
        atmosphereMass: AstronomicalMass,
        surfacePressure: SurfacePressure?,
        bondAlbedo: Double,
        liquidWaterCoverage: Double,
        waterIceCoverage: Double
    ) {
        precondition(
            incidentFluxEarth.isFinite && incidentFluxEarth >= 0,
            "Incident flux must be finite and nonnegative."
        )
        precondition(Self.acceptsUnitFraction(bondAlbedo), "Bond albedo must be finite in 0...1.")
        precondition(Self.acceptsUnitFraction(liquidWaterCoverage), "Liquid-water coverage must be finite in 0...1.")
        precondition(Self.acceptsUnitFraction(waterIceCoverage), "Water-ice coverage must be finite in 0...1.")
        self.incidentFluxEarth = incidentFluxEarth
        self.equilibriumTemperature = equilibriumTemperature
        self.visibleBoundaryTemperature = visibleBoundaryTemperature
        self.atmosphereMass = atmosphereMass
        self.surfacePressure = surfacePressure
        self.bondAlbedo = bondAlbedo
        self.liquidWaterCoverage = liquidWaterCoverage
        self.waterIceCoverage = waterIceCoverage
    }

    private static func acceptsUnitFraction(_ value: Double) -> Bool {
        value.isFinite && value >= 0 && value <= 1
    }
}
