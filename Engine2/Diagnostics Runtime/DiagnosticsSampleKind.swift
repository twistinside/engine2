/// Stable sample kinds used for aggregation, filtering, and exported schemas.
enum DiagnosticsSampleKind: String, Codable, CaseIterable, Hashable, Sendable {
    case inputReceive
    case inputSnapshot
    case presentationSnapshot
    case simulationRuntimeInventory
    case simulationPoll
    case simulationStep
    case systemUpdate
}
