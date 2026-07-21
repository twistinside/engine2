/// Stable signpost names used by Instruments and capture tooling.
enum DiagnosticsSignpostName: String, CaseIterable, Sendable {
    case inputReceive = "InputReceive"
    case inputSnapshotPublish = "InputSnapshotPublish"
    case simulationPoll = "SimulationPoll"
    case simulationStep = "SimulationStep"
    case systemUpdate = "SystemUpdate"
    case presentationSnapshotCapture = "PresentationSnapshotCapture"
    case renderFrameCPU = "RenderFrameCPU"
    case frameSlotWait = "FrameSlotWait"
    case renderProjection = "RenderProjection"
    case frameEncode = "FrameEncode"
    case gpuFrame = "GPUFrame"
    case assetLoad = "AssetLoad"
    case pipelineCompile = "PipelineCompile"
}
