/// Immutable input treatment applied at the safe boundary of an advance.
///
/// Ingestion derives this Simulation consumer's transients from its existing
/// baseline. Rebasing establishes a new baseline without replaying historical
/// cumulative motion. A transition assignment first installs a captured
/// baseline and then ingests a subsequent publication, preserving only input
/// that accumulated after the transition began. The assignment is carried with
/// the request so input cannot change independently while the requested ticks
/// execute.
nonisolated enum SimulationInputAssignment: Sendable {
    case none
    case ingest(InputSnapshot)
    case rebase(InputSnapshot)

    /// Atomically establishes `baseline`, then ingests `snapshot` at the first
    /// requested tick boundary. Same-session cumulative transients are derived
    /// between the two values; persistent state comes from `snapshot`.
    case rebaseThenIngest(
        baseline: InputSnapshot,
        snapshot: InputSnapshot
    )
}
