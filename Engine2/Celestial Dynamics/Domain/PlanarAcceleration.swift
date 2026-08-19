import simd

/// Finite acceleration in the authoritative two-dimensional orbital plane.
nonisolated struct PlanarAcceleration: Codable, Equatable, Sendable {
    static let zero = PlanarAcceleration(metersPerSecondSquared: .zero)

    let metersPerSecondSquared: SIMD2<Double>

    init(metersPerSecondSquared: SIMD2<Double>) {
        precondition(
            metersPerSecondSquared.isFinite,
            "A planar acceleration must contain finite meters per second squared."
        )
        self.metersPerSecondSquared = metersPerSecondSquared
    }
}
