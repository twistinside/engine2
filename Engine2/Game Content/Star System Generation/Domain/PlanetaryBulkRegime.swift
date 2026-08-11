/// Derived dominant bulk composition of a resolved body.
nonisolated enum PlanetaryBulkRegime: UInt8, Codable, Equatable, Hashable, Sendable {
    case metalRich
    case rocky
    case volatileRich
    case hydrogenHeliumDominated
}
