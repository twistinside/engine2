/// Dimensionless eccentricity of one bound Keplerian orbit.
nonisolated struct OrbitalEccentricity: Codable, Equatable, Hashable, RawRepresentable, Sendable {
    static let circular = OrbitalEccentricity(rawValue: 0)

    let rawValue: Double

    init(rawValue: Double) {
        precondition(
            (0..<1).contains(rawValue),
            "A bound orbital eccentricity must be finite in 0..<1."
        )
        self.rawValue = rawValue
    }
}
