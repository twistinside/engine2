/// Closed failures for structural validation and absolute ephemeris evaluation.
nonisolated enum PlanarEphemerisError: Error, Equatable, Sendable {
    case missingRoot
    case multipleRoots
    case invalidRootID(CelestialBodyID)
    case duplicateBodyID(CelestialBodyID)
    case bodiesNotOrdered(previous: CelestialBodyID, current: CelestialBodyID)
    case missingParent(body: CelestialBodyID, parent: CelestialBodyID)
    case hierarchyCycle(CelestialBodyID)
    case nonfiniteState(CelestialBodyID)
}
