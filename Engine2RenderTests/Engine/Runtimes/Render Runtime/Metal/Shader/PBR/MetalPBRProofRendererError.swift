/// Explicit construction and submission failures from the direct PBR proof.
enum MetalPBRProofRendererError: Error {
    case missingCommandAllocator
    case missingParametersBuffer
    case missingColorTexture
    case missingCommandBuffer
    case missingRenderEncoder
    case missingPipeline(PBRProofOutput)
    case timedOut
    case unusableAfterTimeout
}
