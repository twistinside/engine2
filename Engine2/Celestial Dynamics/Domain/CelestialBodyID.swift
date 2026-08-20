/// Stable identity for one body in a celestial-dynamics calculation.
///
/// Identity zero names the primary star. Other identities retain their meaning
/// across ECS materialization, store ordering, and detached prediction work.
nonisolated struct CelestialBodyID: Codable, Equatable, Hashable, RawRepresentable, Sendable {
    static let primaryStar = CelestialBodyID(rawValue: 0)

    let rawValue: UInt64

    init(rawValue: UInt64) {
        self.rawValue = rawValue
    }
}

extension CelestialBodyID: Comparable {
    nonisolated static func < (lhs: CelestialBodyID, rhs: CelestialBodyID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
