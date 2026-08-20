/// Failure that prevents the ECS orbital-dynamics system from committing a tick.
///
/// The system validates and calculates a detached result before it mutates any
/// orbital component or the shared celestial timeline. These failures therefore
/// leave the last committed celestial state intact.
enum OrbitalDynamicsSystemError: Error, Equatable {
    case componentCardinalityMismatch
    case missingIndexedEntity(CelestialBodyID)
    case missingCelestialIdentity(CelestialBodyID)
    case celestialIdentityMismatch(CelestialBodyID)
    case missingMassiveBody(CelestialBodyID)
    case missingOrbitalMotion(CelestialBodyID)
    case missingGravityParticipation(CelestialBodyID)
    case missingEphemerisConfiguration
    case invalidPrescribedGravityParticipation(CelestialBodyID)
    case prescribedStateMismatch(CelestialBodyID)
    case unrepresentableNextEpoch
    case ephemeris(PlanarEphemerisError)
    case mechanics(PlanarOrbitalDynamicsError)
    case resultModelVersionMismatch
    case resultBodyOrderMismatch
}
