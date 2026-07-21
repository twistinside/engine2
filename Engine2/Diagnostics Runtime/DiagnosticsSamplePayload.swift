/// Typed payloads retained by the diagnostics model.
///
/// New cases should carry explicit units and domain identities rather than
/// presentation strings so exports remain repeatable and machine-readable.
enum DiagnosticsSamplePayload: Codable, Equatable, Sendable {
    case presentationSnapshot(PresentationSnapshotDiagnostics)
    case simulationRuntimeInventory(SimulationRuntimeInventoryDiagnostics)
    case simulationPoll(SimulationPollDiagnostics)
    case simulationStep(SimulationStepDiagnostics)
    case systemUpdate(SystemUpdateDiagnostics)
}
