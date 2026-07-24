import Metal

/// Encodes the ordered HDR scene and drawable-presentation phases of a frame.
///
/// The caller supplies only the geometry commands belonging inside the first
/// encoder. This type owns the dependency boundary between phases so production
/// rendering and offscreen validation cannot silently diverge on attachment
/// policy, the Metal 4 producer barrier, or presentation ordering.
@MainActor
final class MetalHDRFramePass {
    private let presentationPass: MetalHDRPresentationPass

    init(resources: MetalResourceStore) throws {
        self.presentationPass = try MetalHDRPresentationPass(
            resources: resources
        )
    }

    /// Encodes scene geometry followed by full-screen presentation.
    ///
    /// `encodeScene` configures the supplied first-phase encoder and emits all
    /// opaque draws. After the closure returns, this method stores their HDR
    /// output, establishes fragment-write visibility for the following fragment
    /// reads, and encodes the selected presentation variant.
    func encode(
        sceneColorTexture: any MTLTexture,
        depthTexture: any MTLTexture,
        destinationTexture: any MTLTexture,
        clearColor: MTLClearColor,
        presentationParametersBuffer: any MTLBuffer,
        outputMode: RenderOutputMode,
        into commandBuffer: any MTL4CommandBuffer,
        encodeScene: (any MTL4RenderCommandEncoder) -> Void
    ) throws {
        let sceneRenderPassDescriptor = Self.makeSceneRenderPassDescriptor(
            sceneColorTexture: sceneColorTexture,
            depthTexture: depthTexture,
            clearColor: clearColor
        )
        guard let sceneEncoder = commandBuffer.makeRenderCommandEncoder(
            descriptor: sceneRenderPassDescriptor,
            options: []
        ) else {
            throw MetalFrameEncoderError.missingSceneEncoder
        }

        encodeScene(sceneEncoder)

        // The presentation encoder samples the texture written by this scene
        // encoder. Metal 4 requires the producer dependency to be explicit.
        sceneEncoder.barrier(
            afterStages: .fragment,
            beforeQueueStages: .fragment,
            visibilityOptions: .device
        )
        sceneEncoder.endEncoding()

        guard presentationPass.encode(
            sceneColorTexture: sceneColorTexture,
            destinationTexture: destinationTexture,
            parametersBuffer: presentationParametersBuffer,
            outputMode: outputMode,
            into: commandBuffer
        ) else {
            throw MetalFrameEncoderError.missingPresentationEncoder
        }
    }

    /// Builds the opaque scene descriptor independently of MetalKit's drawable
    /// descriptor so tests can lock the HDR, store, and depth conventions.
    static func makeSceneRenderPassDescriptor(
        sceneColorTexture: any MTLTexture,
        depthTexture: any MTLTexture,
        clearColor: MTLClearColor
    ) -> MTL4RenderPassDescriptor {
        let descriptor = MTL4RenderPassDescriptor()
        descriptor.colorAttachments[0].texture = sceneColorTexture
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[0].clearColor = clearColor
        descriptor.depthAttachment.texture = depthTexture
        descriptor.depthAttachment.loadAction = .clear
        descriptor.depthAttachment.storeAction = .dontCare
        descriptor.depthAttachment.clearDepth = MetalFrameEncoder.clearDepth
        return descriptor
    }
}
