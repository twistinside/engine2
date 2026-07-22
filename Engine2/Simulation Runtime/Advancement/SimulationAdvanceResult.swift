/// Correlated output from a successfully completed exact Simulation advance.
///
/// Both cursors and the committed count make the cursor range explicit. The
/// final snapshot is the immutable presentation value produced by this
/// request, avoiding a later race against a changing latest-value publication.
nonisolated struct SimulationAdvanceResult: Equatable, Sendable {
    let initialCursor: SimulationCursor
    let finalCursor: SimulationCursor
    let completedStepCount: SimulationCompletedStepCount
    let finalPresentationSnapshot: SimulationPresentationSnapshot
}
