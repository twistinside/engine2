/// Identity of one committed position in a Simulation session.
///
/// The session qualification keeps equal tick values from different rebuilt,
/// restored, or forked timelines from being mistaken for the same state.
public nonisolated struct SimulationCursor: Codable, Hashable, Sendable {
    public let sessionID: SimulationSessionID
    public let tick: SimulationTick

    public init(sessionID: SimulationSessionID, tick: SimulationTick) {
        self.sessionID = sessionID
        self.tick = tick
    }

    /// Returns the next cursor in the same uninterrupted session.
    public func advanced() -> SimulationCursor {
        SimulationCursor(sessionID: sessionID, tick: tick.advanced())
    }
}
