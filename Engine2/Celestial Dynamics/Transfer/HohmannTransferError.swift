/// Refusal reasons for the first circular-reference Hohmann planner.
nonisolated enum HohmannTransferError: Error, Equatable, Sendable {
    case unknownBody(GeneratedBodyID)
    case identicalBodies(GeneratedBodyID)
    case requiresPlanet(GeneratedBodyID)
    case departureBeforeReferenceEpoch
    case coincidentReferenceOrbits
}
