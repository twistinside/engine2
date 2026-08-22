/// Typed refusal from one collective Newtonian gravity evaluation.
///
/// Every index addresses the evaluator's original participant array.
nonisolated enum NewtonianGravityEvaluationError: Error, Equatable, Sendable {
    /// The indexed source mass was nonfinite or not positive.
    case invalidSourceMass(bodyIndex: Int)

    /// The indexed physical radius was nonfinite or negative.
    case invalidPhysicalRadius(bodyIndex: Int)

    /// The indexed position contained a nonfinite coordinate.
    case invalidPosition(bodyIndex: Int)

    /// The indexed source mass did not produce a representable positive Newtonian parameter.
    case unrepresentableGravitationalParameter(bodyIndex: Int)

    /// The indexed participants touch or overlap in an active source-receiver interaction.
    case contact(firstBodyIndex: Int, secondBodyIndex: Int)

    /// The indexed source-receiver pair could not produce finite, nonzero acceleration.
    case unrepresentableInteraction(firstBodyIndex: Int, secondBodyIndex: Int)

    /// Summing valid pair contributions overflowed for the indexed receiver.
    case unrepresentableAcceleration(bodyIndex: Int)
}
