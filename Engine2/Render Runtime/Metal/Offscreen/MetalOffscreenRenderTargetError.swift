/// Closed Metal-backend failures specific to offscreen target ownership.
nonisolated enum MetalOffscreenRenderTargetError: Error, Equatable, Sendable {
    case invalidFrameResourceCount(Int)
    case missingModel(MeshID)
    case modelHasIncompleteDrawableIndexedGeometry(MeshID)
    case missingDestinationTexture(RenderPixelSize)
    case missingDepthTexture(RenderPixelSize)
    case missingCommandBuffer
    case missingReadbackStorage(byteCount: Int)
}
