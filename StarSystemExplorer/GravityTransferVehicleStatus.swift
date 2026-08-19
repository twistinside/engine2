/// Phase of one symbolic vehicle along a circular-reference transfer.
///
/// Departure begins `inFlight`. Arrival and every later displayed epoch use
/// `atArrivalReference`, so presentation never wraps around the transfer rail.
nonisolated enum GravityTransferVehicleStatus: Equatable, Sendable {
    case awaitingDeparture
    case inFlight
    case atArrivalReference
}
