import simd

/// Finite position in the authoritative two-dimensional orbital plane.
///
/// Physics stores meters in `Double`. Presentation code may project this value
/// into a three-dimensional Render coordinate system without feeding that
/// projection back into Simulation.
nonisolated struct PlanarPosition: Codable, Equatable, Sendable {
    static let zero = PlanarPosition(meters: .zero)

    let meters: SIMD2<Double>

    init(meters: SIMD2<Double>) {
        precondition(meters.isFinite, "A planar position must contain finite meters.")
        self.meters = meters
    }

    /// Returns the position produced by composing one parent-relative position.
    func adding(_ relativePosition: PlanarPosition) -> PlanarPosition {
        PlanarPosition(meters: meters + relativePosition.meters)
    }
}
