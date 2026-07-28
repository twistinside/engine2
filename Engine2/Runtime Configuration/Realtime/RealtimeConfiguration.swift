/// Immutable recipe for constructing the application's current real-time topology.
///
/// The configuration carries policy values, while ``RealtimeAssembly`` owns the
/// graph construction and live Runtime instances created from those values.
/// Specialized hosts and tests can select different policy without adding
/// optional peers or mode switches to the real-time assembly.
nonisolated struct RealtimeConfiguration: Equatable, Sendable {
    let pollInterval: Duration
    let catchUpPolicy: RealtimeCatchUpPolicy

    init(pollInterval: Duration, catchUpPolicy: RealtimeCatchUpPolicy) {
        precondition(pollInterval > .zero, "Real-time polling requires a positive interval.")
        self.pollInterval = pollInterval
        self.catchUpPolicy = catchUpPolicy
    }

    /// Supplies explicit content and policy to one self-building assembly.
    @MainActor
    func makeAssembly(gameContent: BasicGameContent) -> RealtimeAssembly {
        RealtimeAssembly(gameContent: gameContent, configuration: self)
    }
}
