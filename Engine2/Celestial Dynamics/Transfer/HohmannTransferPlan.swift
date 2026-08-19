/// Deterministic two-impulse transfer between circular references around one primary.
///
/// Source and destination identities retain generated-body provenance. The
/// transfer uses their semimajor axes as explicit circular reference radii; it
/// does not claim rendezvous with either body's eccentric generated rail.
/// Presentation samples `transferRail` through
/// ``PlanarKeplerPropagationKernel``.
nonisolated struct HohmannTransferPlan: Codable, Equatable, Sendable {
    let sourceBodyID: GeneratedBodyID
    let destinationBodyID: GeneratedBodyID
    let primaryBodyID: GeneratedBodyID?
    let sourceReferenceRadius: AstronomicalDistance
    let destinationReferenceRadius: AstronomicalDistance
    let nextWindowWait: AstronomicalDuration
    let departureEpoch: CelestialEpoch
    let arrivalEpoch: CelestialEpoch
    let transferDuration: AstronomicalDuration
    let requiredPhaseAngleRadians: Double
    let departureDeltaVMetersPerSecond: Double
    let arrivalDeltaVMetersPerSecond: Double
    let totalDeltaVMetersPerSecond: Double
    let transferRail: PlanarKeplerianRail
}
