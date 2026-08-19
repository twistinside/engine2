/// Complete planar position and velocity at one celestial epoch.
///
/// The state is suitable for rail evaluation, trajectory prediction, and a
/// future transition into dynamic gravity without reconstructing velocity from
/// adjacent positions.
nonisolated struct PlanarStateVector: Codable, Equatable, Sendable {
    static let zero = PlanarStateVector(position: .zero, velocity: .zero)

    let position: PlanarPosition
    let velocity: PlanarVelocity

    /// Composes this parent-relative state with its parent's absolute state.
    func composed(withParent parentState: PlanarStateVector) -> PlanarStateVector {
        PlanarStateVector(
            position: parentState.position.adding(position),
            velocity: parentState.velocity.adding(velocity)
        )
    }
}
