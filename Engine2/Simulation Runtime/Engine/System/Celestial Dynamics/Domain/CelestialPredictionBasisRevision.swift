/// Monotonic revision of the committed facts that determine future trajectories.
///
/// Ordinary advancement along the expected trajectory does not change this
/// revision. Impulses, authority transitions, gravity-source changes, and
/// other interventions advance it and invalidate predictions from an older
/// basis.
nonisolated struct CelestialPredictionBasisRevision: Codable, Hashable, RawRepresentable, Sendable {
    static let zero = CelestialPredictionBasisRevision(rawValue: 0)

    let rawValue: UInt64
}

extension CelestialPredictionBasisRevision: Comparable {
    static func < (
        lhs: CelestialPredictionBasisRevision,
        rhs: CelestialPredictionBasisRevision
    ) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
