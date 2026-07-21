/// Stable sample kinds used for aggregation, filtering, and exported schemas.
enum DiagnosticsSampleKind: String, Codable, CaseIterable, Hashable, Sendable {
    case assetLoad
    case frameEncode
    case frameSlotWait
    case inputReceive
    case inputSnapshot
    case presentationSnapshot
    case pipelineCompile
    case renderFrameCPU
    case renderProjection
    case renderResourceFailure
    case renderResourceInventory
    case simulationRuntimeInventory
    case simulationPoll
    case simulationStep
    case systemUpdate
}
