import Engine2
import Engine2AssemblySupport
/// Converts elapsed wall time into bounded batches of complete Simulation steps.
///
/// This value owns only external elapsed-time debt. Consuming a batch never
/// advances Simulation or changes cursor identity; the real-time driver remains
/// responsible for submitting the resulting exact request.
nonisolated struct RealtimeStepAccumulator {
    let fixedTimeStep: Duration
    let catchUpPolicy: RealtimeCatchUpPolicy
    private(set) var elapsedRemainder: Duration

    /// Starts without elapsed-time debt under one fixed batching policy.
    init(fixedTimeStep: Duration, catchUpPolicy: RealtimeCatchUpPolicy) {
        precondition(fixedTimeStep > .zero, "Real-time advancement requires a positive fixed time step.")
        self.fixedTimeStep = fixedTimeStep
        self.catchUpPolicy = catchUpPolicy
        self.elapsedRemainder = .zero
    }

    /// Adds one elapsed sample and removes at most one configured wake budget.
    mutating func consumeSteps(adding elapsed: Duration) -> SimulationStepCount? {
        elapsedRemainder += elapsed

        guard elapsedRemainder >= fixedTimeStep else {
            return nil
        }

        var rawStepCount: UInt32 = 0
        let maximumStepCount = catchUpPolicy.maximumStepsPerWake.rawValue
        while elapsedRemainder >= fixedTimeStep,
              rawStepCount < maximumStepCount {
            elapsedRemainder -= fixedTimeStep
            rawStepCount += 1
        }

        if elapsedRemainder >= fixedTimeStep,
           catchUpPolicy.backlogTreatment == .discardOverflow {
            // Once at least one additional whole step overflows the cap, real-
            // time responsiveness wins over wall-clock catch-up. Cursor space
            // remains contiguous because no Simulation step was requested or
            // skipped; only external elapsed-time debt is discarded.
            elapsedRemainder = .zero
        }

        return SimulationStepCount(rawValue: rawStepCount)
    }

    /// Permanently drops elapsed work that has not become a Simulation request.
    mutating func reset() {
        elapsedRemainder = .zero
    }
}
