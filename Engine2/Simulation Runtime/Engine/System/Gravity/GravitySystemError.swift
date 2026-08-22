/// Typed refusal from `SGravity.accumulateGravity(in:)` before it commits an acceleration batch.
///
/// Every associated entity is a stable `World` handle. A caller may correct or
/// resolve the identified state and retry because a refusal leaves every motion
/// accumulator unchanged.
nonisolated enum GravitySystemError: Error, Equatable, Sendable {
    /// The source entity supplied nonfinite or nonpositive mass.
    case invalidSourceMass(entity: EntityID)

    /// The entity supplied nonfinite or negative physical radius.
    case invalidPhysicalRadius(entity: EntityID)

    /// The entity supplied a position containing a nonfinite coordinate.
    case invalidPosition(entity: EntityID)

    /// The source entity's mass did not produce a representable positive Newtonian parameter.
    case unrepresentableGravitationalParameter(entity: EntityID)

    /// The entities touch or overlap in an active source-receiver interaction.
    case contact(firstEntity: EntityID, secondEntity: EntityID)

    /// The entities could not produce finite, nonzero acceleration.
    case unrepresentableInteraction(firstEntity: EntityID, secondEntity: EntityID)

    /// Summing valid pair contributions overflowed for the receiver entity.
    case unrepresentableAcceleration(entity: EntityID)

    /// Adding a completed gravity contribution would make the receiver's accumulator nonfinite.
    case unrepresentableAccumulator(entity: EntityID)
}
