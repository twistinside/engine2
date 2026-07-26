import Metal

/// Second render phase that turns linear scene color into drawable color.
///
/// Surface output uses manual exposure and Reinhard tone mapping. Diagnostics
/// use the sibling linear pipeline so their 0...1 meanings remain intact. Both
/// pipelines write display-linear values to the sRGB drawable, which performs
/// the only transfer encoding in the visible pathway.
final class MetalHDRPresentationPass {
    private let toneMappedPipeline: any MTLRenderPipelineState
    private let linearPipeline: any MTLRenderPipelineState
    private let argumentTable: any MTL4ArgumentTable

    init(resources: MetalResourceStore) {
        let requiredResources = resources.requiredResources
        self.toneMappedPipeline = requiredResources.hdrToneMappedPresentationPipeline
        self.linearPipeline = requiredResources.linearPresentationPipeline
        self.argumentTable = requiredResources.hdrPresentationArgumentTable
    }

    /// Encodes the full-screen presentation pass.
    ///
    /// The caller establishes the fragment-to-fragment producer barrier at the
    /// end of the scene encoder before invoking this method. Keeping exactly
    /// one synchronization point makes the two-phase dependency inspectable.
    func encode(
        sceneColorTexture: any MTLTexture,
        destinationTexture: any MTLTexture,
        parametersBuffer: any MTLBuffer,
        outputMode: RenderOutputMode,
        into commandBuffer: any MTL4CommandBuffer
    ) throws(MetalFrameEncoderError) {
        let renderPass = Self.makeRenderPassDescriptor(
            destinationTexture: destinationTexture
        )
        guard let encoder = commandBuffer.makeRenderCommandEncoder(
            descriptor: renderPass,
            options: []
        ) else {
            throw .missingPresentationEncoder
        }

        encoder.setRenderPipelineState(pipeline(for: outputMode))

        argumentTable.setTexture(
            sceneColorTexture.gpuResourceID,
            index: 0
        )
        argumentTable.setAddress(parametersBuffer.gpuAddress, index: 0)
        encoder.setArgumentTable(argumentTable, stages: .fragment)
        encoder.drawPrimitives(
            primitiveType: .triangle,
            vertexStart: 0,
            vertexCount: 3
        )
        encoder.endEncoding()
    }

    /// Descriptor factory kept visible to tests because the resulting encoder
    /// does not expose which attachment policy created it.
    static func makeRenderPassDescriptor(destinationTexture: any MTLTexture) -> MTL4RenderPassDescriptor {
        let descriptor = MTL4RenderPassDescriptor()
        descriptor.colorAttachments[0].texture = destinationTexture
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: 0,
            green: 0,
            blue: 0,
            alpha: 1
        )
        return descriptor
    }

    private func pipeline(for outputMode: RenderOutputMode) -> any MTLRenderPipelineState {
        switch outputMode {
        case .surface:
            toneMappedPipeline

        case .viewSpaceNormals:
            linearPipeline
        }
    }
}
