/// Stable identities for Engine2's invariant Simulation Runtime systems.
///
/// This closed vocabulary describes the foundational schedule owned by the
/// engine. A future consumer-defined system extension point will need its own
/// deliberately open identity boundary.
enum SimulationSystemID: String, Codable, CaseIterable, Sendable {
    case inputMapping
    case cameraInput
    case inputHistory
    case inputCleanup
    case accelerationIntent
    case movement
    case rotation
}
