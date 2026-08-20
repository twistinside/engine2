/// Closed failures that prevent one deterministic planar orbital step.
nonisolated enum PlanarOrbitalDynamicsError: Error, Equatable, Sendable {
    case invalidDurationSeconds
    case duplicateBodyID(CelestialBodyID)
    case bodiesNotOrdered(previous: CelestialBodyID, current: CelestialBodyID)
    case invalidMass(CelestialBodyID)
    case sourceRequiresPositiveMass(CelestialBodyID)
    /// The source mass cannot produce a positive finite Newtonian parameter.
    case unrepresentableGravitationalParameter(CelestialBodyID)
    case invalidRadius(CelestialBodyID)
    case nonfiniteState(CelestialBodyID)
    /// One active gravity interaction reached or crossed the bodies' combined radii.
    case contact(first: CelestialBodyID, second: CelestialBodyID)
    case nonfiniteAcceleration(CelestialBodyID)
}
