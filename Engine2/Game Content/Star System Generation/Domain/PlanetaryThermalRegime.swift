/// Derived temperature regime at the visible boundary.
nonisolated enum PlanetaryThermalRegime: UInt8, Codable, Equatable, Hashable, Sendable {
    case frozen
    case temperate
    case hot
    case molten
}
