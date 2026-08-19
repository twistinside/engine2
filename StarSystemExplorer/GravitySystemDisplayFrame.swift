/// One immutable, epoch-qualified projection consumed by the Dynamics workspace.
///
/// The frame publishes body lookup, selected gravity, and transfer-vehicle
/// presentation atomically. Static rail geometry remains outside this value so
/// advancing playback does not rebuild it.
nonisolated struct GravitySystemDisplayFrame: Equatable, Sendable {
    let epoch: CelestialEpoch
    let bodyStates: [GravityBodyState]
    let selectedGravityAccelerationMetersPerSecondSquared: Double?
    let transferVehicleState: GravityTransferVehicleState?

    private let bodyStatesByID: [GeneratedBodyID: PlanarStateVector]

    var elapsedSeconds: Double {
        epoch.secondsSinceReferenceEpoch
    }

    init(
        epoch: CelestialEpoch,
        bodyStates: [GravityBodyState],
        selectedGravityAccelerationMetersPerSecondSquared: Double?,
        transferVehicleState: GravityTransferVehicleState?
    ) {
        self.epoch = epoch
        self.bodyStates = bodyStates
        self.selectedGravityAccelerationMetersPerSecondSquared =
            selectedGravityAccelerationMetersPerSecondSquared
        self.transferVehicleState = transferVehicleState
        self.bodyStatesByID = Dictionary(
            uniqueKeysWithValues: bodyStates.map { ($0.body.id, $0.state) }
        )
    }

    /// Returns one absolute state without scanning the ordered frame array.
    func state(for bodyID: GeneratedBodyID) -> PlanarStateVector? {
        bodyStatesByID[bodyID]
    }
}
