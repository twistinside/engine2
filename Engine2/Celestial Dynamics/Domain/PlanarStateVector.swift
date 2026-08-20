/// Complete planar position and velocity at one celestial epoch.
///
/// Rail evaluation and numerical dynamics exchange this value directly, so an
/// authority transition does not need to reconstruct velocity from adjacent
/// positions.
nonisolated struct PlanarStateVector: Codable, Equatable, Sendable {
    static let zero = PlanarStateVector(position: .zero, velocity: .zero)

    let position: PlanarPosition
    let velocity: PlanarVelocity

}
