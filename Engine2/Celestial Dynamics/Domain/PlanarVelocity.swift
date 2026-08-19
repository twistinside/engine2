import simd

/// Finite velocity in the authoritative two-dimensional orbital plane.
nonisolated struct PlanarVelocity: Codable, Equatable, Sendable {
    static let zero = PlanarVelocity(metersPerSecond: .zero)

    let metersPerSecond: SIMD2<Double>

    init(metersPerSecond: SIMD2<Double>) {
        precondition(metersPerSecond.isFinite, "A planar velocity must contain finite meters per second.")
        self.metersPerSecond = metersPerSecond
    }

    /// Returns the velocity produced by composing one parent-relative velocity.
    func adding(_ relativeVelocity: PlanarVelocity) -> PlanarVelocity {
        PlanarVelocity(metersPerSecond: metersPerSecond + relativeVelocity.metersPerSecond)
    }
}
