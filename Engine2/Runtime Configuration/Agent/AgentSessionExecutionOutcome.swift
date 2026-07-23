/// Terminal result of one accepted and sequence-consuming agent request.
///
/// Both capture forms consume the same monotonic identity even though only an
/// advancing source can change the authoritative Simulation cursor.
nonisolated enum AgentSessionExecutionOutcome: Equatable, Sendable {
    /// Exact terminal output from an advance-then-capture workflow.
    case capture(OfflineCaptureOutcome)

    /// Exact terminal output from capture of an already completed cursor.
    case currentCapture(OfflineCurrentCaptureOutcome)

    /// The identity was accepted but its requested batch exceeded session policy.
    ///
    /// This result is retained and replayed like any other accepted terminal so
    /// changing the payload at the consumed identity cannot make it executable.
    case stepLimitExceeded(
        requested: SimulationStepCount,
        maximum: SimulationStepCount
    )
}
