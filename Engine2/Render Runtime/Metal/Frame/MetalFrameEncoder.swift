import Metal
import MetalKit

/// Prepares and encodes the reusable Metal 4 work for one render frame.
///
/// This object owns backend resource resolution, frame-buffer packing, the HDR
/// scene/presentation pass, and model draw encoding. Command-buffer lifetime,
/// frame-slot arbitration, drawable ownership, queue submission, presentation,
/// source sampling, and terminal-error policy remain with the caller so the
/// same exact encoder can serve screen and offscreen configurations.
@MainActor
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
    private let depthStencilState: any MTLDepthStencilState
    private let modelArgumentTable: any MTL4ArgumentTable
    private let pbrSceneArgumentTable: any MTL4ArgumentTable
    private let hdrFramePass: MetalHDRFramePass

    /// Creates an encoder backed by the store's eagerly prepared Metal state.
    init(resources: MetalResourceStore) throws {
        self.resources = resources
        self.pbrPipelineState = try resources.renderPipelineState(for: .modelPBR)
        self.normalDiagnosticPipelineState = try resources.renderPipelineState(
            for: .modelNormalDiagnostic
        )
        self.depthStencilState = try resources.depthStencilState(for: .opaque)
        self.modelArgumentTable = try resources.argumentTable(for: .model)
        self.pbrSceneArgumentTable = try resources.argumentTable(for: .pbrScene)
        self.hdrFramePass = try MetalHDRFramePass(resources: resources)
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
    ) throws {
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
            sceneEncoder.setRenderPipelineState(
                renderPipelineState(for: inputs.outputMode)
            )
            sceneEncoder.setDepthStencilState(depthStencilState)

            // The directional light is constant for the frame. Each draw adds
            // its own stable instance address to this fragment-stage table.
            pbrSceneArgumentTable.setAddress(
                frameResources.pbrSceneParametersBuffer.gpuAddress,
                index: 2
            )
            draw(
                prepared,
                frame: frameResources,
                with: sceneEncoder
            )
        }
    }

    /// Resolves a closed output mode to an eagerly compiled pipeline.
    private func renderPipelineState(
        for outputMode: RenderOutputMode
    ) -> any MTLRenderPipelineState {
        switch outputMode {
        case .surface:
            pbrPipelineState

        case .viewSpaceNormals:
            normalDiagnosticPipelineState
        }
    }

    /// Emits ordered model draws for the exact set packed into this frame slot.
    private func draw(
        _ prepared: MetalPreparedFrame,
        frame: FrameResources,
        with renderEncoder: any MTL4RenderCommandEncoder
    ) {
        for (instanceIndex, instance) in prepared.instances.enumerated() {
            // Missing model content makes only this live-screen instance
            // unrenderable. Exact offscreen work proves model coverage before
            // preparing the frame and cannot reach this branch.
            guard let model = instance.model else {
                continue
            }

            frame.bindInstance(
                at: instanceIndex,
                modelArgumentTable: modelArgumentTable,
                pbrSceneArgumentTable: pbrSceneArgumentTable,
                to: renderEncoder
            )

            for mesh in model.meshes {
                guard let vertexBuffer = mesh.vertexBuffers.first else {
                    continue
                }

                // MetalKit may suballocate mesh buffers from a larger buffer,
                // so the bound GPU address must include its slice offset.
                modelArgumentTable.setAddress(
                    vertexBuffer.buffer.gpuAddress + UInt64(vertexBuffer.offset),
                    index: 0
                )
                renderEncoder.setArgumentTable(
                    modelArgumentTable,
                    stages: .vertex
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
}
