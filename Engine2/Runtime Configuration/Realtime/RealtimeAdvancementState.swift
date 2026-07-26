/// Mutually exclusive user policy and authority health for real-time advance.
///
/// Lifecycle polling remains an independent concern: a paused driver may keep
/// polling, while a stopped driver may preserve enabled policy for a later run.
/// A cursor fault instead retains its exact mismatch and cannot simultaneously
/// advertise that advancement is enabled.
nonisolated enum RealtimeAdvancementState: Equatable, Sendable {
    case enabled
    case paused
    case faulted(RealtimeAdvanceDriverFault)
}
