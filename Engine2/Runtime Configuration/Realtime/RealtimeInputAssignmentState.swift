/// Captured Input cutover policy for one real-time Simulation connection.
///
/// A replacement advances the private policy generation even when the new
/// baseline equals the old value. Completed work may therefore retire only the
/// exact baseline generation that traveled with its request.
nonisolated struct RealtimeInputAssignmentState: Sendable {
    private var transitionBaseline: InputSnapshot?
    private var generation: UInt64

    /// Starts without a transition baseline or prior policy mutation.
    init() {
        self.transitionBaseline = nil
        self.generation = 0
    }

    /// Replaces transition policy while invalidating stale request bookkeeping.
    mutating func replaceTransitionBaseline(_ baseline: InputSnapshot?) {
        precondition(generation < .max, "Real-time input policy generation exhausted.")
        generation += 1
        transitionBaseline = baseline
    }

    /// Forms the immutable treatment that travels with one exact request.
    func assignment(ingesting snapshot: InputSnapshot?) -> SimulationInputAssignment {
        switch (transitionBaseline, snapshot) {
        case let (.some(baseline), .some(snapshot)):
            .rebaseThenIngest(
                baseline: baseline,
                snapshot: snapshot
            )

        case let (.some(baseline), .none):
            .rebase(baseline)

        case let (.none, .some(snapshot)):
            .ingest(snapshot)

        case (.none, .none):
            .none
        }
    }

    /// Clears a committed baseline unless newer policy superseded its request.
    mutating func retireTransitionBaseline(ifUnchangedSince requestState: Self) {
        guard generation == requestState.generation else {
            return
        }
        transitionBaseline = nil
    }
}
