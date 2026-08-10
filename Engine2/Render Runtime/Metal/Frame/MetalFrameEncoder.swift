import Metal
import MetalKit

/// Prepares and encodes the reusable Metal 4 work for one render frame.
///
/// This object owns backend resource resolution, frame-buffer packing, the HDR
/// scene/presentation pass, and model draw encoding. Command-buffer lifetime,
/// frame-slot arbitration, drawable ownership, queue submission, presentation,
/// source sampling, and terminal-error policy remain with the caller so the
/// same exact encoder can serve screen and offscreen configurations.
final class MetalFrameEncoder {
    /// Linear half-float scene format retained until presentation.
    static let sceneColorPixelFormat = MTLPixelFormat.rgba16Float

    /// Standard display/output format written by the presentation pass.
    static let destinationColorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb

    /// Ordinary floating-point depth used by the opaque model pass.
    static let depthPixelFormat = MTLPixelFormat.depth32Float

    /// Ordinary depth clear used with the `.less` comparison.
    static let clearDepth = 1.0

    private let resources: MetalResourceStore
    private let pbrPipelineState: any MTLRenderPipelineState
    private let normalDiagnosticPipelineState: any MTLRenderPipelineState
    private let terrestrialPlanetSurfacePipelineState: any MTLRenderPipelineState
    private let terrestrialPlanetNormalDiagnosticPipelineState: any MTLRenderPipelineState
    private let terrestrialPlanetCloudPipelineState: any MTLRenderPipelineState
    private let terrestrialPlanetAtmospherePipelineState: any MTLRenderPipelineState
    private let opaqueDepthStencilState: any MTLDepthStencilState
    private let translucentDepthStencilState: any MTLDepthStencilState
    private let modelArgumentTable: any MTL4ArgumentTable
    private let pbrSceneArgumentTable: any MTL4ArgumentTable
    private let terrestrialPlanetArgumentTable: any MTL4ArgumentTable
    private let hdrFramePass: MetalHDRFramePass

    /// Creates an encoder backed by the store's eagerly prepared Metal state.
    init(resources: MetalResourceStore) {
        let requiredResources = resources.requiredResources
        self.resources = resources
        self.pbrPipelineState = requiredResources.modelPBRPipeline
        self.normalDiagnosticPipelineState = requiredResources.modelNormalDiagnosticPipeline
        self.terrestrialPlanetSurfacePipelineState = requiredResources
            .terrestrialPlanetSurfacePipeline
        self.terrestrialPlanetNormalDiagnosticPipelineState = requiredResources
            .terrestrialPlanetNormalDiagnosticPipeline
        self.terrestrialPlanetCloudPipelineState = requiredResources
            .terrestrialPlanetCloudPipeline
        self.terrestrialPlanetAtmospherePipelineState = requiredResources
            .terrestrialPlanetAtmospherePipeline
        self.opaqueDepthStencilState = requiredResources
            .opaqueDepthStencilState
        self.translucentDepthStencilState = requiredResources
            .translucentDepthStencilState
        self.modelArgumentTable = requiredResources.modelArgumentTable
        self.pbrSceneArgumentTable = requiredResources.pbrSceneArgumentTable
        self.terrestrialPlanetArgumentTable = requiredResources
            .terrestrialPlanetArgumentTable
        self.hdrFramePass = MetalHDRFramePass(resources: resources)
    }

    /// Resolves every authored resource in the exact writable instance prefix.
    ///
    /// This method performs no mutable GPU work. A missing material therefore
    /// cannot first appear after allocator reset, buffer writes, or command
    /// encoding: the store proved complete material coverage at construction.
    func prepare(_ renderFrame: RenderFrame) -> MetalPreparedFrame {
        MetalPreparedFrame(renderFrame: renderFrame, resources: resources)
    }

    /// Writes one prepared frame and records its HDR scene and presentation work.
    ///
    /// The validated inputs carry matching targets and one caller-owned frame
    /// slot. The caller owns the active Metal 4 command buffer; this method
    /// neither begins nor ends that lifetime.
    func encode(
        _ prepared: MetalPreparedFrame,
        inputs: MetalFrameEncodingInputs,
        into commandBuffer: any MTL4CommandBuffer
    ) throws(MetalFrameEncoderError) {
        let frameResources = inputs.frameResources
        frameResources.write(
            prepared,
            drawableSize: inputs.drawableSize,
            exposure: inputs.exposure
        )

        try hdrFramePass.encode(
            sceneColorTexture: inputs.sceneColorTexture,
            depthTexture: inputs.depthTexture,
            destinationTexture: inputs.destinationTexture,
            clearColor: inputs.clearColor,
            presentationParametersBuffer: frameResources.hdrPresentationParametersBuffer,
            outputMode: inputs.outputMode,
            into: commandBuffer
        ) { sceneEncoder in
            // The directional light is constant for the frame. Each draw adds
            // its own stable instance address to this fragment-stage table.
            pbrSceneArgumentTable.setAddress(
                frameResources.pbrSceneParametersBuffer.gpuAddress,
                index: 2
            )
            terrestrialPlanetArgumentTable.setAddress(
                frameResources.pbrSceneParametersBuffer.gpuAddress,
                index: 2
            )
            encodeScene(
                prepared,
                outputMode: inputs.outputMode,
                frame: frameResources,
                with: sceneEncoder
            )
        }
    }

    /// Emits the complete ordered scene for one production output mode.
    private func encodeScene(
        _ prepared: MetalPreparedFrame,
        outputMode: RenderOutputMode,
        frame: FrameResources,
        with renderEncoder: any MTL4RenderCommandEncoder
    ) {
        renderEncoder.setCullMode(.none)
        renderEncoder.setDepthStencilState(opaqueDepthStencilState)

        switch outputMode {
        case .surface:
            renderEncoder.setRenderPipelineState(pbrPipelineState)
            drawOpaquePBR(
                prepared,
                frame: frame,
                with: renderEncoder
            )
            renderEncoder.setFrontFacing(.counterClockwise)
            renderEncoder.setCullMode(.back)
            renderEncoder.setRenderPipelineState(
                terrestrialPlanetSurfacePipelineState
            )
            drawTerrestrialPlanets(
                prepared,
                frame: frame,
                with: renderEncoder
            )

            renderEncoder.setDepthStencilState(translucentDepthStencilState)
            renderEncoder.setRenderPipelineState(
                terrestrialPlanetCloudPipelineState
            )
            drawTerrestrialPlanets(
                prepared,
                frame: frame,
                with: renderEncoder
            )
            renderEncoder.setRenderPipelineState(
                terrestrialPlanetAtmospherePipelineState
            )
            drawTerrestrialPlanets(
                prepared,
                frame: frame,
                with: renderEncoder
            )

        case .viewSpaceNormals:
            renderEncoder.setRenderPipelineState(
                normalDiagnosticPipelineState
            )
            drawOpaquePBR(
                prepared,
                frame: frame,
                with: renderEncoder
            )
            renderEncoder.setFrontFacing(.counterClockwise)
            renderEncoder.setCullMode(.back)
            renderEncoder.setRenderPipelineState(
                terrestrialPlanetNormalDiagnosticPipelineState
            )
            drawTerrestrialPlanets(
                prepared,
                frame: frame,
                with: renderEncoder
            )
        }
    }

    /// Emits ordinary opaque PBR model draws in source order.
    private func drawOpaquePBR(
        _ prepared: MetalPreparedFrame,
        frame: FrameResources,
        with renderEncoder: any MTL4RenderCommandEncoder
    ) {
        for (instanceIndex, instance) in prepared.instances.enumerated() {
            // Missing model content makes only this live-screen instance
            // unrenderable. Exact offscreen work validates the models retained
            // by its prepared frame and cannot reach this branch.
            guard let model = instance.model else {
                continue
            }

            frame.bindInstance(
                at: instanceIndex,
                modelArgumentTable: modelArgumentTable,
                pbrSceneArgumentTable: pbrSceneArgumentTable,
                to: renderEncoder
            )

            drawIndexedModel(
                model,
                argumentTable: modelArgumentTable,
                stages: .vertex,
                with: renderEncoder
            )
        }
    }

    /// Emits one selected layer for every prepared terrestrial planet.
    ///
    /// The selected pipeline determines whether the shared geometry produces
    /// smooth surface, clouds, atmosphere, or normal diagnostics.
    private func drawTerrestrialPlanets(
        _ prepared: MetalPreparedFrame,
        frame: FrameResources,
        with renderEncoder: any MTL4RenderCommandEncoder
    ) {
        for (instanceIndex, instance) in prepared
            .terrestrialPlanetInstances.enumerated() {
            guard let model = instance.model else {
                continue
            }

            bind(
                instance.resources,
                to: terrestrialPlanetArgumentTable
            )
            frame.bindTerrestrialPlanetInstance(
                at: instanceIndex,
                argumentTable: terrestrialPlanetArgumentTable,
                to: renderEncoder
            )
            drawIndexedModel(
                model,
                argumentTable: terrestrialPlanetArgumentTable,
                stages: .vertex.union(.fragment),
                with: renderEncoder
            )
        }
    }

    /// Installs one planet appearance's complete generated-map set.
    private func bind(
        _ resources: MetalTerrestrialPlanetResources,
        to argumentTable: any MTL4ArgumentTable
    ) {
        argumentTable.setTexture(
            resources.normalTexture.gpuResourceID,
            index: 0
        )
        argumentTable.setTexture(
            resources.surfaceTexture.gpuResourceID,
            index: 1
        )
        argumentTable.setTexture(
            resources.controlTexture.gpuResourceID,
            index: 2
        )
        argumentTable.setTexture(
            resources.cloudTexture.gpuResourceID,
            index: 3
        )
    }

    /// Emits every complete indexed draw in one decoded model.
    private func drawIndexedModel(
        _ model: USDRenderModel,
        argumentTable: any MTL4ArgumentTable,
        stages: MTLRenderStages,
        with renderEncoder: any MTL4RenderCommandEncoder
    ) {
        for mesh in model.meshes {
            guard let vertexBuffer = mesh.vertexBuffers.first else {
                continue
            }

            // MetalKit may suballocate mesh buffers from a larger buffer, so
            // the bound GPU address must include its slice offset.
            argumentTable.setAddress(
                vertexBuffer.buffer.gpuAddress + UInt64(vertexBuffer.offset),
                index: 0
            )
            renderEncoder.setArgumentTable(
                argumentTable,
                stages: stages
            )

            for submesh in mesh.submeshes {
                let indexBuffer = submesh.indexBuffer

                renderEncoder.drawIndexedPrimitives(
                    primitiveType: submesh.primitiveType,
                    indexCount: submesh.indexCount,
                    indexType: submesh.indexType,
                    indexBuffer: indexBuffer.buffer.gpuAddress
                        + UInt64(indexBuffer.offset),
                    indexBufferLength: indexBuffer.length
                )
            }
        }
    }
}
