/// Typed payloads retained by the diagnostics model.
///
/// New cases should carry explicit units and domain identities rather than
/// presentation strings so exports remain repeatable and machine-readable.
enum DiagnosticsSamplePayload: Codable, Equatable, Sendable {
    case frameEncode(FrameEncodeDiagnostics)
    case frameSlotWait(FrameSlotWaitDiagnostics)
    case inputReceive(InputReceiveDiagnostics)
    case inputSnapshot(InputSnapshotDiagnostics)
    case presentationSnapshot(PresentationSnapshotDiagnostics)
    case renderFrameCPU(RenderFrameCPUDiagnostics)
    case renderProjection(RenderProjectionDiagnostics)
    case simulationRuntimeInventory(SimulationRuntimeInventoryDiagnostics)
    case simulationPoll(SimulationPollDiagnostics)
    case simulationStep(SimulationStepDiagnostics)
    case systemUpdate(SystemUpdateDiagnostics)

    var kind: DiagnosticsSampleKind {
        switch self {
        case .frameEncode: .frameEncode
        case .frameSlotWait: .frameSlotWait
        case .inputReceive: .inputReceive
        case .inputSnapshot: .inputSnapshot
        case .presentationSnapshot: .presentationSnapshot
        case .renderFrameCPU: .renderFrameCPU
        case .renderProjection: .renderProjection
        case .simulationRuntimeInventory: .simulationRuntimeInventory
        case .simulationPoll: .simulationPoll
        case .simulationStep: .simulationStep
        case .systemUpdate: .systemUpdate
        }
    }

    var durationNanoseconds: UInt64? {
        switch self {
        case .inputReceive, .inputSnapshot, .simulationRuntimeInventory:
            nil
        case let .frameEncode(payload):
            payload.durationNanoseconds
        case let .frameSlotWait(payload):
            payload.durationNanoseconds
        case let .presentationSnapshot(payload):
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
