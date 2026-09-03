/// Complete result of asking a Simulation Runtime to advance exactly.
///
/// Rejection carries no partial result because the Runtime refuses stale work
/// before applying input or beginning the first requested tick.
nonisolated enum SimulationAdvanceOutcome: Equatable, Sendable {
    case completed(SimulationAdvanceResult)
    case rejected(SimulationAdvanceRejection)
}
