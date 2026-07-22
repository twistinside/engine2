/// Narrow directed capability for exact Simulation Runtime advancement.
///
/// The asynchronous, nonisolated contract permits callers to invoke a target
/// without learning whether its implementation is main-actor isolated, owns a
/// dedicated actor, or uses another concurrency-safe serialization policy.
nonisolated protocol PSimulationAdvanceTarget: AnyObject, Sendable {
    func advance(_ request: SimulationAdvanceRequest) async -> SimulationAdvanceOutcome
}
