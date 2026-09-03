/// Generation-tagged one-shot command staged by the real-time assembly.
///
/// A request captures this value before crossing the asynchronous Simulation
/// boundary. Completion retires only the captured generation, so a later UI
/// command received while that request is in flight remains pending.
nonisolated struct RealtimeOrbitCircularizationCommandState: Sendable {
    private(set) var command: OrbitCircularizationCommand?
    private var generation: UInt64

    init() {
        self.command = nil
        self.generation = 0
    }

    /// Replaces the pending one-shot command with a newer user decision.
    mutating func stage(_ command: OrbitCircularizationCommand) {
        advanceGeneration()
        self.command = command
    }

    /// Discards any pending command and invalidates in-flight bookkeeping.
    mutating func clear() {
        guard command != nil else {
            return
        }

        advanceGeneration()
        command = nil
    }

    /// Retires the command carried by a completed request unless a newer one superseded it.
    mutating func retire(ifUnchangedSince requestState: Self) {
        guard generation == requestState.generation else {
            return
        }
        command = nil
    }

    private mutating func advanceGeneration() {
        precondition(generation < .max, "Real-time orbit-command generation exhausted.")
        generation += 1
    }
}
