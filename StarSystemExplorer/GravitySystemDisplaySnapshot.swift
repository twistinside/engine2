/// One immutable, epoch-qualified projection consumed by the Dynamics workspace.
///
/// The snapshot publishes body lookup, selected gravity, and transfer-vehicle
/// presentation atomically. Static rail geometry remains outside this value so
/// advancing playback does not resample it.
nonisolated struct GravitySystemDisplaySnapshot: Equatable, Sendable {
    let epoch: CelestialEpoch
    let ephemerisSnapshot: GravitySystemEphemerisSnapshot?
    let selectedGravityState: GravitySystemSelectedGravityState
    let transferVehicleState: GravityTransferVehicleState?

    var elapsedSeconds: Double {
        epoch.secondsSinceReferenceEpoch
    }

    var bodyStates: [GravityBodyState] {
        ephemerisSnapshot?.bodyStates ?? []
    }

    init(
        ephemerisSnapshot: GravitySystemEphemerisSnapshot,
        selectedGravityState: GravitySystemSelectedGravityState,
        transferVehicleState: GravityTransferVehicleState?
    ) {
        epoch = ephemerisSnapshot.epoch
        self.ephemerisSnapshot = ephemerisSnapshot
        self.selectedGravityState = selectedGravityState
        self.transferVehicleState = transferVehicleState
    }

    private init(
        epoch: CelestialEpoch,
        ephemerisSnapshot: GravitySystemEphemerisSnapshot?,
        selectedGravityState: GravitySystemSelectedGravityState,
        transferVehicleState: GravityTransferVehicleState?
    ) {
        self.epoch = epoch
        self.ephemerisSnapshot = ephemerisSnapshot
        self.selectedGravityState = selectedGravityState
        self.transferVehicleState = transferVehicleState
    }

    /// Creates a snapshot for an epoch with no available gravity projection.
    static func unavailable(at epoch: CelestialEpoch) -> Self {
        Self(
            epoch: epoch,
            ephemerisSnapshot: nil,
            selectedGravityState: .unavailable,
            transferVehicleState: nil
        )
    }

    /// Returns one absolute state without scanning the ordered snapshot array.
    func state(for bodyID: GeneratedBodyID) -> PlanarStateVector? {
        ephemerisSnapshot?.state(for: bodyID)
    }
}
