/// Detached next states produced by one complete numerical orbital step.
///
/// Body states retain the input's strict identity order. A Simulation system can
/// validate this value before committing every component row and its shared
/// celestial epoch as one logical operation.
nonisolated struct PlanarOrbitalDynamicsStepResult: Equatable, Sendable {
    let modelVersion: PlanarOrbitalDynamicsModelVersion
    let bodyStates: [PlanarOrbitalBodyState]

    /// Returns one propagated state without exposing mutable storage.
    func state(for bodyID: CelestialBodyID) -> PlanarStateVector? {
        bodyStates.first { $0.id == bodyID }?.state
    }
}
