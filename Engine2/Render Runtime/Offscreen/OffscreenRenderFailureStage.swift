/// Closed lifecycle stage at which an accepted offscreen render failed.
nonisolated enum OffscreenRenderFailureStage: Equatable, Hashable, Sendable {
    case preparation
    case targetAllocation
    case commandBufferCreation
    case encoding
    case gpuExecution
    case readback
}
