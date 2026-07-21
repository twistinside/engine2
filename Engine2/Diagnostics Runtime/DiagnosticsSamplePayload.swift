/// Typed payloads retained by the diagnostics model.
///
/// New cases should carry explicit units and domain identities rather than
/// presentation strings so exports remain repeatable and machine-readable.
enum DiagnosticsSamplePayload: Codable, Equatable, Sendable {
    case assetLoad(AssetLoadDiagnostics)
    case frameEncode(FrameEncodeDiagnostics)
    case frameSlotWait(FrameSlotWaitDiagnostics)
    case inputReceive(InputReceiveDiagnostics)
    case inputSnapshot(InputSnapshotDiagnostics)
    case presentationSnapshot(PresentationSnapshotDiagnostics)
    case pipelineCompile(PipelineCompileDiagnostics)
    case renderFrameCPU(RenderFrameCPUDiagnostics)
    case renderProjection(RenderProjectionDiagnostics)
    case renderResourceFailure(RenderResourceFailureDiagnostics)
    case renderResourceInventory(RenderResourceInventoryDiagnostics)
    case simulationRuntimeInventory(SimulationRuntimeInventoryDiagnostics)
    case simulationPoll(SimulationPollDiagnostics)
    case simulationStep(SimulationStepDiagnostics)
    case systemUpdate(SystemUpdateDiagnostics)

    var kind: DiagnosticsSampleKind {
        switch self {
        case .assetLoad: .assetLoad
        case .frameEncode: .frameEncode
        case .frameSlotWait: .frameSlotWait
        case .inputReceive: .inputReceive
        case .inputSnapshot: .inputSnapshot
        case .presentationSnapshot: .presentationSnapshot
        case .pipelineCompile: .pipelineCompile
        case .renderFrameCPU: .renderFrameCPU
        case .renderProjection: .renderProjection
        case .renderResourceFailure: .renderResourceFailure
        case .renderResourceInventory: .renderResourceInventory
        case .simulationRuntimeInventory: .simulationRuntimeInventory
        case .simulationPoll: .simulationPoll
        case .simulationStep: .simulationStep
        case .systemUpdate: .systemUpdate
        }
    }

    var durationNanoseconds: UInt64? {
        switch self {
        case .inputReceive, .inputSnapshot, .renderResourceFailure, .renderResourceInventory,
             .simulationRuntimeInventory:
            nil
        case let .assetLoad(payload):
            payload.durationNanoseconds
        case let .frameEncode(payload):
            payload.durationNanoseconds
        case let .frameSlotWait(payload):
            payload.durationNanoseconds
        case let .presentationSnapshot(payload):
            payload.durationNanoseconds
        case let .pipelineCompile(payload):
            payload.durationNanoseconds
        case let .renderFrameCPU(payload):
            payload.durationNanoseconds
        case let .renderProjection(payload):
            payload.durationNanoseconds
        case let .simulationPoll(payload):
            payload.durationNanoseconds
        case let .simulationStep(payload):
            payload.durationNanoseconds
        case let .systemUpdate(payload):
            payload.durationNanoseconds
        }
    }
}
