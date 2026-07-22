/// Immutable input treatment applied at the safe boundary of an advance.
///
/// Ingestion derives this Simulation consumer's transients from its existing
/// baseline. Rebasing establishes a new baseline without replaying historical
/// cumulative motion. The assignment is carried with the request so input
/// cannot change independently while the requested ticks execute.
nonisolated enum SimulationInputAssignment: Sendable {
    case none
    case ingest(InputSnapshot)
    case rebase(InputSnapshot)
}
