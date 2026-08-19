/// Symbolic vehicle presentation derived from one Hohmann reference plan.
///
/// The position is a display value only. It does not represent an executed
/// spacecraft, authoritative Simulation state, or rendezvous with an eccentric
/// generated body.
nonisolated struct GravityTransferVehicleState: Equatable, Sendable {
    let status: GravityTransferVehicleStatus
    let position: PlanarPosition
}
