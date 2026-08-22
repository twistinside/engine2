/// Deterministic two-impulse transfer between circular references around one primary.
///
/// Source and destination identities retain generated-body provenance. The
/// transfer uses their semimajor axes as explicit circular reference radii; it
/// does not claim rendezvous with either body's eccentric generated rail.
/// Presentation samples `transferRail` through
/// ``PlanarKeplerPropagationKernel``. The plan retains its planning, departure,
/// and arrival epochs so its wait and travel durations cannot diverge.
nonisolated struct HohmannTransferPlan: Equatable, Sendable {
    let sourceBodyID: GeneratedBodyID
    let destinationBodyID: GeneratedBodyID
    let sourceReferenceRadius: AstronomicalDistance
    let destinationReferenceRadius: AstronomicalDistance
    let planningEpoch: CelestialEpoch
    let departureEpoch: CelestialEpoch
    let arrivalEpoch: CelestialEpoch
    let requiredPhaseAngleRadians: Double
    let departureDeltaVMetersPerSecond: Double
    let arrivalDeltaVMetersPerSecond: Double
    let transferRail: PlanarKeplerianRail

    var nextWindowWait: AstronomicalDuration {
        departureEpoch.duration(since: planningEpoch)
    }

    var transferDuration: AstronomicalDuration {
        arrivalEpoch.duration(since: departureEpoch)
    }

    var totalDeltaVMetersPerSecond: Double {
        departureDeltaVMetersPerSecond + arrivalDeltaVMetersPerSecond
    }
}
