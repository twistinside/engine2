/// Stable sample kinds used for aggregation, filtering, and exported schemas.
enum DiagnosticsSampleKind: String, Codable, CaseIterable, Hashable, Sendable {
    case frameEncode
    case frameSlotWait
    case inputReceive
    case inputSnapshot
    case presentationSnapshot
    case renderFrameCPU
    case renderProjection
    case simulationRuntimeInventory
    case simulationPoll
    case simulationStep
    case systemUpdate
}
