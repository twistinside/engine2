/// Terminal result of one accepted and sequence-consuming agent request.
nonisolated enum AgentSessionExecutionOutcome: Equatable, Sendable {
    /// Exact terminal output from the existing serial offline workflow.
    case capture(OfflineCaptureOutcome)

    /// The identity was accepted but its requested batch exceeded session policy.
    ///
    /// This result is retained and replayed like any other accepted terminal so
    /// changing the payload at the consumed identity cannot make it executable.
    case stepLimitExceeded(
        requested: SimulationStepCount,
        maximum: SimulationStepCount
    )
}
