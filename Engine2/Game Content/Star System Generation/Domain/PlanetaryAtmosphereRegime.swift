/// Derived present-day atmospheric depth without prescribing appearance.
///
/// `airless` requires exactly zero resolved atmosphere mass. Any positive
/// exposed atmosphere below the secondary-pressure threshold is `tenuous`.
nonisolated enum PlanetaryAtmosphereRegime: UInt8, Codable, Equatable, Hashable, Sendable {
    case airless
    case tenuous
    case secondary
    case deepEnvelope
}
