/// World-owned provenance for prescribed celestial-state evaluation.
///
/// A World retains this resource when any body's orbital authority uses the
/// analytic ephemeris. Integrated-only Worlds do not require it because their
/// motion does not depend on a rail model.
struct CelestialEphemerisConfiguration: PResource, Equatable, Sendable {
    let modelVersion: CelestialDynamicsModelVersion
}
