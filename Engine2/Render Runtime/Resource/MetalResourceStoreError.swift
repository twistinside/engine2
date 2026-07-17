/// Failures that can prevent construction or use of a Metal resource store.
nonisolated enum MetalResourceStoreError: Error, Equatable {
    case missingDevice
    case missingCommandQueue
    case invalidFrameCount(Int)
    case missingDefaultShaderLibrary
    case missingShaderLibrary(MetalShaderLibraryID)
    case missingRenderPipeline(MetalRenderPipelineID)
    case missingDepthStencilState(MetalDepthStencilStateID)
    case missingArgumentTable(MetalArgumentTableID)
    case missingFrameResource
}
