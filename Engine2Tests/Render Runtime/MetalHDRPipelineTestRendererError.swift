/// Construction and submission failures from the visible HDR GPU proof.
enum MetalHDRPipelineTestRendererError: Error {
    case missingFrame
    case missingVertexBuffer
    case missingSceneTexture
    case missingDepthTexture
    case missingPresentedTexture
    case missingCommandBuffer
    case timedOut
    case unusableAfterTimeout
}
