/// Failures that can prevent construction or use of a Metal resource store.
nonisolated enum MetalResourceStoreError: Error, Equatable {
    case missingDevice
    case missingCommandQueue
    case invalidFrameCount(Int)
    case missingDefaultShaderLibrary
    case missingOpaqueDepthStencilState
    case missingFrameResource
    case missingHDRSceneTarget
}
