/// Absolute planar state paired with its generated rail-body facts.
nonisolated struct GravityBodyState: Equatable, Sendable {
    let body: GravityRailBody
    let state: PlanarStateVector
}
