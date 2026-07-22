/// Identity of one committed position in a Simulation session.
///
/// The session qualification keeps equal tick values from different rebuilt,
/// restored, or forked timelines from being mistaken for the same state.
nonisolated struct SimulationCursor: Codable, Hashable, Sendable {
    let sessionID: SimulationSessionID
    let tick: SimulationTick

    /// Returns the next cursor in the same uninterrupted session.
    func advanced() -> SimulationCursor {
        SimulationCursor(sessionID: sessionID, tick: tick.advanced())
    }
}
