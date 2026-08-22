/// Projects one circular-reference transfer into symbolic vehicle presentation state.
///
/// Before departure, the vehicle remains at the transfer rail's departure
/// endpoint. During flight, the shared Kepler kernel evaluates the displayed
/// epoch. At and after arrival, the vehicle remains at the arrival endpoint.
nonisolated struct GravityTransferVehicleProjection: Sendable {
    private let propagationKernel: PlanarKeplerPropagationKernel

    init(
        propagationKernel: PlanarKeplerPropagationKernel = PlanarKeplerPropagationKernel()
    ) {
        self.propagationKernel = propagationKernel
    }

    /// Returns deterministic symbolic state for one displayed epoch.
    func state(
        for plan: HohmannTransferPlan,
        at displayedEpoch: CelestialEpoch
    ) -> GravityTransferVehicleState {
        let status: GravityTransferVehicleStatus
        let evaluationEpoch: CelestialEpoch
        if displayedEpoch < plan.departureEpoch {
            status = .awaitingDeparture
            evaluationEpoch = plan.departureEpoch
        } else if displayedEpoch < plan.arrivalEpoch {
            status = .inFlight
            evaluationEpoch = displayedEpoch
        } else {
            status = .atArrivalReference
            evaluationEpoch = plan.arrivalEpoch
        }
        return GravityTransferVehicleState(
            status: status,
            position: propagationKernel.state(
                on: plan.transferRail,
                at: evaluationEpoch
            ).position
        )
    }
}
