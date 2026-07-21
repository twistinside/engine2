import Metal

/// Second render phase that turns linear scene color into drawable color.
///
/// Surface output uses manual exposure and Reinhard tone mapping. Diagnostics
/// use the sibling linear pipeline so their 0...1 meanings remain intact. Both
/// pipelines write display-linear values to the sRGB drawable, which performs
/// the only transfer encoding in the visible pathway.
@MainActor
final class MetalHDRPresentationPass {
    private let toneMappedPipeline: any MTLRenderPipelineState
    private let linearPipeline: any MTLRenderPipelineState
    private let argumentTable: any MTL4ArgumentTable

    init(resources: MetalResourceStore) throws {
        self.toneMappedPipeline = try resources.renderPipelineState(
            for: .hdrToneMappedPresentation
        )
        self.linearPipeline = try resources.renderPipelineState(
            for: .linearPresentation
        )
        self.argumentTable = try resources.argumentTable(
            for: .hdrPresentation
        )
    }

    /// Encodes the full-screen presentation pass.
    ///
    /// The caller establishes the fragment-to-fragment producer barrier at the
    /// end of the scene encoder before invoking this method. Keeping exactly
    /// one synchronization point makes the two-phase dependency inspectable.
    /// Returning `false` means no encoder was created and no presentation work
    /// was recorded; the caller must abandon rather than submit a partial frame.
    func encode(
        sceneColorTexture: any MTLTexture,
        destinationTexture: any MTLTexture,
        parametersBuffer: any MTLBuffer,
        outputMode: RenderOutputMode,
        into commandBuffer: any MTL4CommandBuffer
    ) -> Bool {
        let renderPass = Self.makeRenderPassDescriptor(
            destinationTexture: destinationTexture
        )
        guard let encoder = commandBuffer.makeRenderCommandEncoder(
            descriptor: renderPass,
            options: []
        ) else {
            return false
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
        return true
    }

    /// Descriptor factory kept visible to tests because the resulting encoder
    /// does not expose which attachment policy created it.
    static func makeRenderPassDescriptor(
        destinationTexture: any MTLTexture
    ) -> MTL4RenderPassDescriptor {
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

    private func pipeline(
        for outputMode: RenderOutputMode
    ) -> any MTLRenderPipelineState {
        switch outputMode {
        case .surface:
            toneMappedPipeline

        case .viewSpaceNormals:
            linearPipeline
        }
    }
}
