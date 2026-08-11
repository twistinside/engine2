/// Resolved fractions of the visible solid boundary covered by liquid water and ice.
nonisolated struct PlanetaryWaterCoverage: Sendable {
    static let none = PlanetaryWaterCoverage(liquid: 0, ice: 0)

    let liquid: Double
    let ice: Double
}
