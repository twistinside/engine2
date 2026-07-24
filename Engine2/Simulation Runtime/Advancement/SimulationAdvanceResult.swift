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

    /// Creates one internally coherent completed range and final publication.
    ///
    /// A completed result is a Simulation-owned exactness boundary, not an
    /// arbitrary transport bag. Enforcing its cursor arithmetic here prevents
    /// every coordinator and output consumer from having to decide which of
    /// several contradictory identities to trust.
    init(
        initialCursor: SimulationCursor,
        finalCursor: SimulationCursor,
        completedStepCount: SimulationCompletedStepCount,
        finalPresentationSnapshot: SimulationPresentationSnapshot
    ) {
        precondition(
            completedStepCount.rawValue > 0,
            "A completed Simulation advance must contain at least one step."
        )
        precondition(
            initialCursor.sessionID == finalCursor.sessionID,
            "A completed Simulation advance cannot cross session identity."
        )

        let (expectedFinalTick, overflowed) =
            initialCursor.tick.rawValue.addingReportingOverflow(
                UInt64(completedStepCount.rawValue)
            )
        precondition(
            !overflowed && finalCursor.tick.rawValue == expectedFinalTick,
            "A completed Simulation cursor range must match its step count."
        )
        precondition(
            finalPresentationSnapshot.cursor == finalCursor,
            "A completed Simulation result must publish its final cursor."
        )

        self.initialCursor = initialCursor
        self.finalCursor = finalCursor
        self.completedStepCount = completedStepCount
        self.finalPresentationSnapshot = finalPresentationSnapshot
    }
}
