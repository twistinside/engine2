/// Represents the complete player-visible state of circular-reference transfer planning.
enum GravityTransferState {
    /// The generated system contains no selectable planet.
    case noPlanets

    /// The only generated planet cannot form a source-destination pair.
    case onePlanet(GeneratedBodyID)

    /// A source-destination pair has not been selected.
    case selectionIncomplete

    /// Gravity-system generation failed before transfer planning could begin.
    case projectionUnavailable(GravitySystemGenerationError)

    /// The selected pair produced one circular-reference plan.
    case ready(HohmannTransferPlan)

    /// The planner rejected the selected pair or departure baseline.
    case failed(HohmannTransferError)
}
