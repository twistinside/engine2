/// Derived present-day state of the body's accessible water inventory.
nonisolated enum PlanetaryWaterRegime: UInt8, Codable, Equatable, Hashable, Sendable {
    case dry
    case iceCovered
    case partialLiquid
    case globalOcean
    case steam
    case inaccessible
}
