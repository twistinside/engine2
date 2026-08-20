/// Closed physical classification used by celestial entity facades and persistence.
///
/// Dynamics authority and gravity participation remain independent. A comet can
/// therefore follow a rail or use integrated motion without changing its kind.
nonisolated enum CelestialBodyKind: UInt8, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case star = 0
    case planet = 1
    case moon = 2
    case comet = 3
    case asteroid = 4
}
