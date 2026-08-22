import simd

/// Detached source and receiver facts for one collective gravity evaluation.
///
/// `sourceMass` supplies gravity when present. `receivesGravity` requests one
/// acceleration result. A participant may fill either role or both; one
/// participant never acts on itself. `physicalRadius` defines its contact
/// boundary even when the participant is only a receiver.
nonisolated struct NewtonianGravityParticipant: Equatable, Sendable {
    let sourceMass: AstronomicalMass?
    let physicalRadius: AstronomicalDistance
    let positionMeters: SIMD3<Double>
    let receivesGravity: Bool
}
