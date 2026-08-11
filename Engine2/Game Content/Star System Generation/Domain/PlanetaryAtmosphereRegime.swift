/// Derived present-day atmospheric depth without prescribing appearance.
nonisolated enum PlanetaryAtmosphereRegime: UInt8, Codable, Equatable, Hashable, Sendable {
    case airless
    case tenuous
    case secondary
    case deepEnvelope
}
