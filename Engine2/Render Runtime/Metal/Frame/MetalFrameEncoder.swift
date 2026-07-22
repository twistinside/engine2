import CoreGraphics
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

    /// Resolves every authored material in the exact writable instance prefix.
    ///
    /// This method performs no mutable GPU work. A missing material therefore
    /// fails the frame before allocator reset, buffer writes, or command encoding.
    func prepare(_ renderFrame: RenderFrame) throws -> MetalPreparedFrame {
        let materialDescriptions = try renderFrame.instances
            .prefix(FrameResources.maximumInstanceCount)
            .map { instance in
                try resources.materialDescription(for: instance.materialID)
            }

        return MetalPreparedFrame(
            renderFrame: renderFrame,
            materialDescriptions: materialDescriptions
        )
    }

    /// Writes one prepared frame and records its HDR scene and presentation work.
    ///
    /// All three targets must describe the same positive pixel dimensions. The
    /// caller owns an active Metal 4 command buffer and the supplied frame slot;
    /// this method neither begins nor ends either lifetime.
    func encode(
        _ prepared: MetalPreparedFrame,
        frameResources: FrameResources,
        sceneColorTexture: any MTLTexture,
        depthTexture: any MTLTexture,
        destinationTexture: any MTLTexture,
        clearColor: MTLClearColor,
        outputMode: RenderOutputMode,
        exposure: ManualExposure = .validation,
        into commandBuffer: any MTL4CommandBuffer
    ) throws {
        precondition(
            sceneColorTexture.width > 0
                && sceneColorTexture.height > 0
                && depthTexture.width > 0
                && depthTexture.height > 0
                && destinationTexture.width > 0
                && destinationTexture.height > 0,
            "Metal frame encoding requires positive target dimensions."
        )
        precondition(
            sceneColorTexture.width == depthTexture.width
                && sceneColorTexture.height == depthTexture.height
                && sceneColorTexture.width == destinationTexture.width
                && sceneColorTexture.height == destinationTexture.height,
            "Metal frame encoding requires matching target dimensions."
        )
        precondition(
            sceneColorTexture.pixelFormat == Self.sceneColorPixelFormat
                && depthTexture.pixelFormat == Self.depthPixelFormat
                && destinationTexture.pixelFormat == Self.destinationColorPixelFormat,
            "Metal frame encoding requires targets matching its compiled pipeline formats."
        )

        let renderFrame = prepared.renderFrame
        let instanceCount = frameResources.write(
            renderFrame.instances,
            materialDescriptions: prepared.materialDescriptions,
            camera: renderFrame.camera,
            drawableSize: CGSize(
                width: destinationTexture.width,
                height: destinationTexture.height
            ),
            exposure: exposure
        )

        try hdrFramePass.encode(
            sceneColorTexture: sceneColorTexture,
            depthTexture: depthTexture,
            destinationTexture: destinationTexture,
            clearColor: clearColor,
            presentationParametersBuffer: frameResources.hdrPresentationParametersBuffer,
            outputMode: outputMode,
            into: commandBuffer
        ) { sceneEncoder in
            sceneEncoder.setRenderPipelineState(
                renderPipelineState(for: outputMode)
            )
            sceneEncoder.setDepthStencilState(depthStencilState)

            // The directional light is constant for the frame. Each draw adds
            // its own stable instance address to this fragment-stage table.
            pbrSceneArgumentTable.setAddress(
                frameResources.pbrSceneParametersBuffer.gpuAddress,
                index: 2
            )
            draw(
                renderFrame.instances,
                instanceCount: instanceCount,
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

    /// Emits ordered model draws for the prefix packed into this frame slot.
    private func draw(
        _ instances: [RenderInstance],
        instanceCount: Int,
        frame: FrameResources,
        with renderEncoder: any MTL4RenderCommandEncoder
    ) {
        guard instanceCount > 0 else {
            return
        }

        Self.forEachRenderableModel(
            in: instances,
            instanceCount: instanceCount,
            resources: resources
        ) { instanceIndex, model in
            Self.selectModelInstance(
                at: instanceIndex,
                in: frame,
                modelArgumentTable: modelArgumentTable,
                pbrSceneArgumentTable: pbrSceneArgumentTable,
                with: renderEncoder
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

    /// Visits the exact bounded, model-resolved prefix used by visible draws.
    ///
    /// This internal CPU-side seam owns draw order and missing-model filtering,
    /// allowing integration tests to verify production iteration directly.
    static func forEachRenderableModel(
        in instances: [RenderInstance],
        instanceCount: Int,
        resources: MetalResourceStore,
        _ visit: (_ instanceIndex: Int, _ model: USDRenderModel) -> Void
    ) {
        precondition(
            instanceCount >= 0
                && instanceCount <= instances.count
                && instanceCount <= FrameResources.maximumInstanceCount,
            "Visible model iteration must stay inside the written instance prefix."
        )

        for instanceIndex in 0..<instanceCount {
            // Missing model content makes only this instance unrenderable.
            // Material coverage has already passed the frame's terminal
            // preflight and never falls back here.
            guard let model = resources.model(
                for: instances[instanceIndex].meshID
            ) else {
                continue
            }

            visit(instanceIndex, model)
        }
    }

    /// Selects one stable per-frame instance for both model shader stages.
    ///
    /// The vertex table is rebound after its mesh address is selected. The PBR
    /// fragment table is complete when this helper binds it because frame light
    /// state is installed before entering the draw loop.
    static func selectModelInstance(
        at instanceIndex: Int,
        in frame: FrameResources,
        modelArgumentTable: any MTL4ArgumentTable,
        pbrSceneArgumentTable: any MTL4ArgumentTable,
        with renderEncoder: any MTL4RenderCommandEncoder
    ) {
        precondition(
            instanceIndex >= 0
                && instanceIndex < FrameResources.maximumInstanceCount,
            "Model instance selection must remain inside the frame buffer."
        )

        let instanceAddress = frame.instanceBuffer.gpuAddress
            + UInt64(instanceIndex * MemoryLayout<GPUInstance>.stride)
        modelArgumentTable.setAddress(instanceAddress, index: 1)
        pbrSceneArgumentTable.setAddress(instanceAddress, index: 1)
        renderEncoder.setArgumentTable(
            pbrSceneArgumentTable,
            stages: .fragment
        )
    }
}
