import CoreGraphics
import Foundation
import Metal
import MetalKit

/// Metal 4 backend that renders the latest completed simulation presentation.
///
/// `MetalRenderer` samples a narrow presentation source at render cadence,
/// projects it into private `RenderFrame` data, and encodes GPU work using one
/// device-scoped `MetalResourceStore`. It never reads live ECS storage, and it
/// does not own or control the Simulation Runtime lifecycle.
@MainActor
final class MetalRenderer: NSObject, MTKViewDelegate {
    /// Keep a small ring of per-frame command allocators so the CPU can encode
    /// upcoming frames while the GPU may still be consuming earlier ones.
    static let maximumFramesInFlight = 3

    /// The drawable format must match the color attachment format baked into
    /// the render pipeline state.
    static let colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb

    /// Linear half-float scene color preserves values above display white until
    /// the explicit presentation phase applies exposure and tone mapping.
    static let sceneColorPixelFormat = MTLPixelFormat.rgba16Float

    /// Ordinary floating-point depth used by the opaque model pass.
    static let depthPixelFormat = MTLPixelFormat.depth32Float

    /// Ordinary depth clears to the farthest representable depth so fragments
    /// passing the `.less` comparison replace untouched pixels.
    static let clearDepth = 1.0

    /// Device-scoped owner for every backend object used by this renderer.
    let resources: MetalResourceStore

    /// The MetalKit view must use the same device as the resource store.
    var device: any MTLDevice {
        resources.device
    }

    /// Direct-light PBR pipeline that writes linear radiance to the HDR target.
    private let pbrPipelineState: any MTLRenderPipelineState

    /// Diagnostic pipeline that maps interpolated view-space normals to color.
    private let normalDiagnosticPipelineState: any MTLRenderPipelineState

    /// Opaque depth behavior shared by the surface and normal diagnostic views.
    private let depthStencilState: any MTLDepthStencilState

    /// Geometry resource binding table. Each draw updates buffer slot 0 to point
    /// at the current mesh's vertex buffer and slot 1 to point at the current
    /// render instance before encoding the draw.
    private let modelArgumentTable: any MTL4ArgumentTable

    /// Fragment-stage binding for the current instance and frame-constant light.
    private let pbrSceneArgumentTable: any MTL4ArgumentTable

    /// Ordered scene and presentation phases, including their explicit Metal 4
    /// producer dependency.
    private let hdrFramePass: MetalHDRFramePass

    /// Terminal preparation and asynchronous queue failures are preserved
    /// across frame callbacks. Once one is observed, this renderer stops
    /// submitting additional GPU work; diagnostics can still inspect the
    /// latest failure from work already live.
    private let renderErrorState = MetalRenderErrorState()

    /// Shared App-owned diagnostics boundary; Render emits only typed facts.
    private let diagnostics: DiagnosticsEmitter

    /// Read-only Simulation Runtime publication selected at render cadence.
    /// The App owns the source's lifetime; Render does not retain its peer runtime.
    weak var presentationSource: (any PSimulationPresentationSource)?

    /// Selects the visible output without changing geometry, transforms, depth,
    /// or draw submission. Debug tooling can switch this value at render cadence.
    var outputMode: RenderOutputMode

    /// Latest terminal frame-preparation or asynchronous queue error.
    ///
    /// Exposing the underlying error read-only keeps diagnostics available to
    /// App tooling without making the Render Runtime depend on a UI policy.
    var latestRenderError: (any Error)? {
        renderErrorState.latestError
    }

    /// Index into `frames` for the next draw call.
    private var frameIndex = 0

    init(
        resources: MetalResourceStore,
        presentationSource: any PSimulationPresentationSource,
        outputMode: RenderOutputMode = .surface,
        diagnostics: DiagnosticsEmitter = DiagnosticsEmitter()
    ) throws {
        precondition(
            !resources.frames.isEmpty,
            "MetalRenderer requires at least one frame resource set."
        )

        self.resources = resources
        self.pbrPipelineState = try resources.renderPipelineState(for: .modelPBR)
        self.normalDiagnosticPipelineState = try resources.renderPipelineState(
            for: .modelNormalDiagnostic
        )
        self.depthStencilState = try resources.depthStencilState(for: .opaque)
        self.modelArgumentTable = try resources.argumentTable(for: .model)
        self.pbrSceneArgumentTable = try resources.argumentTable(for: .pbrScene)
        self.hdrFramePass = try MetalHDRFramePass(resources: resources)
        self.presentationSource = presentationSource
        self.outputMode = outputMode
        self.diagnostics = diagnostics

        super.init()
    }

    /// Applies the attachment formats that must agree with the cached pipelines.
    ///
    /// Keeping this policy on the renderer gives the SwiftUI bridge and tests
    /// one source of truth for the color format and ordinary-depth convention.
    static func configureRenderTargets(on view: MTKView) {
        view.colorPixelFormat = colorPixelFormat
        view.depthStencilPixelFormat = depthPixelFormat
        view.clearDepth = clearDepth

        // Fragment shaders return display-linear values. Declaring the view's
        // presentation color space and using an `_srgb` drawable makes the
        // drawable perform the one and only linear-to-sRGB transfer.
        view.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
    }

    /// Configures renderer-owned attachment policy and registers MetalKit-owned
    /// drawable resources for explicit Metal 4 queue residency.
    func configure(_ view: MTKView) {
        Self.configureRenderTargets(on: view)
        resources.residency.registerExternalResources(for: view)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange _: CGSize) {
        // Targets are allocated from the acquired drawable's integer pixel
        // dimensions in `draw(in:)`. Deferring allocation avoids racing a size
        // notification against the actual drawable supplied by MetalKit.
    }

    /// Draws the models selected by the latest immutable render frame.
    func draw(in view: MTKView) {
        // A Metal 4 feedback failure is terminal for this renderer instance.
        // Continuing to submit would reuse state after an unknown GPU failure
        // and would make the original diagnostic harder to reason about.
        guard renderErrorState.latestError == nil else {
            return
        }

        // Pick the next frame slot before touching the drawable. If all slots
        // are still in flight, this applies back pressure here instead of
        // continuing to allocate command memory without bound.
        let frame = nextFrame()
        frame.waitUntilAvailable()

        // While this draw waits, Metal feedback may record a failure on another
        // thread. Recheck after acquiring the slot so a failure that unblocked
        // this very wait cannot trigger one more frame.
        guard renderErrorState.latestError == nil else {
            frame.markAvailable()
            return
        }

        // Sample only after back pressure clears so this draw uses the newest
        // completed Simulation value available when encoding can actually
        // begin. Resolve its exact submitted prefix before resetting mutable
        // GPU state or acquiring a drawable; missing authored content therefore
        // cannot produce a partial frame.
        let renderFrame: RenderFrame
        if let presentationSource {
            renderFrame = diagnostics.measureRenderProjection(
                from: presentationSource.latestPresentationSnapshot
            )
        } else {
            renderFrame = .empty
        }

        let materialDescriptions: [PBRMaterialDescription]
        do {
            materialDescriptions = try resolveMaterialDescriptions(
                for: renderFrame.instances
            )
        } catch {
            renderErrorState.record(error)
            frame.markAvailable()
            return
        }

        // The commit feedback handler marks the frame available only after the
        // GPU finishes the previous workload that used this allocator, so it is
        // safe to recycle the allocator's internal command memory now.
        frame.commandAllocator.reset()

        // Ask MetalKit for the drawable and the Metal 4 render pass descriptor
        // as late as possible. Holding drawable references longer than needed
        // can reduce how much buffering Core Animation has available.
        guard let drawable = view.currentDrawable,
              let viewRenderPassDescriptor = view.currentMTL4RenderPassDescriptor,
              let depthTexture = viewRenderPassDescriptor.depthAttachment.texture,
              let commandBuffer = device.makeCommandBuffer()
        else {
            // No GPU work was submitted for this slot, so release it back to the
            // ring immediately.
            frame.markAvailable()
            return
        }

        // MetalKit can temporarily vend a zero-sized drawable while a view is
        // being resized or removed. Do not feed invalid dimensions into target
        // construction; simply make this frame slot available again.
        let drawableWidth = drawable.texture.width
        let drawableHeight = drawable.texture.height
        guard drawableWidth > 0, drawableHeight > 0 else {
            frame.markAvailable()
            return
        }

        let sceneTarget: MetalHDRSceneTarget
        do {
            // The slot is known to be available, so replacing its old target
            // cannot invalidate a texture referenced by earlier GPU work.
            sceneTarget = try frame.prepareHDRSceneTarget(
                device: device,
                width: drawableWidth,
                height: drawableHeight
            )
        } catch {
            renderErrorState.record(error)
            frame.markAvailable()
            return
        }

        // Drawable ownership is explicit in Metal 4: wait before encoding work
        // that targets it, then signal when submitted work has completed.
        resources.commandQueue.waitForDrawable(drawable)

        // Attach this frame's allocator before encoding. A Metal 4 command
        // buffer does not own command storage until `beginCommandBuffer`.
        commandBuffer.beginCommandBuffer(allocator: frame.commandAllocator)

        // The static and frame-buffer residency sets are registered queue-wide.
        // This drawable-sized target is slot-local, so attach its committed set
        // to the exact command buffer that references it.
        commandBuffer.useResidencySet(sceneTarget.residencySet)

        let instanceCount = frame.write(
            renderFrame.instances,
            materialDescriptions: materialDescriptions,
            camera: renderFrame.camera,
            drawableSize: CGSize(
                width: drawableWidth,
                height: drawableHeight
            )
        )

        // Phase one shades opaque geometry into linear half-float scene color;
        // phase two presents that stored value to the sRGB drawable. The frame
        // pass owns their barrier and ordering so every caller uses one pathway.
        do {
            try hdrFramePass.encode(
                sceneColorTexture: sceneTarget.texture,
                depthTexture: depthTexture,
                destinationTexture: drawable.texture,
                clearColor: viewRenderPassDescriptor.colorAttachments[0].clearColor,
                presentationParametersBuffer: frame.hdrPresentationParametersBuffer,
                outputMode: outputMode,
                into: commandBuffer
            ) { sceneEncoder in
                sceneEncoder.setRenderPipelineState(
                    renderPipelineState(for: outputMode)
                )
                sceneEncoder.setDepthStencilState(depthStencilState)

                // The directional light is constant for the frame. Each draw
                // adds its own instance address to this fragment-stage table,
                // where the shader also reads its packed authored material.
                pbrSceneArgumentTable.setAddress(
                    frame.pbrSceneParametersBuffer.gpuAddress,
                    index: 2
                )
                draw(
                    renderFrame.instances,
                    instanceCount: instanceCount,
                    frame: frame,
                    with: sceneEncoder
                )
            }
        } catch {
            // Encoder creation failures are terminal, unlike a temporarily
            // missing drawable. Preserve the exact error before abandoning the
            // closed command buffer and releasing its unsubmitted frame slot.
            commandBuffer.endCommandBuffer()
            renderErrorState.record(error)
            frame.markAvailable()
            return
        }

        // `endCommandBuffer` makes the recorded work valid for queue submission.
        commandBuffer.endCommandBuffer()

        // An older in-flight frame can fail while this frame is being encoded.
        // Abandon this closed but unsubmitted buffer if that happened; its slot
        // and exact resources are still CPU-owned and immediately reusable.
        guard renderErrorState.latestError == nil else {
            frame.markAvailable()
            return
        }

        // Metal 4 residency is not object ownership. Retain the complete store,
        // the drawable, and this pass's view-owned depth texture independently
        // of the SwiftUI coordinator until queue feedback reports completion.
        let submission = MetalInFlightSubmission(
            resources: resources,
            drawable: drawable,
            depthTexture: depthTexture,
            sceneTarget: sceneTarget,
            frame: frame,
            errorState: renderErrorState
        )

        // Feedback is the point where this renderer learns the GPU is done with
        // the frame's command allocator and referenced resources. Errors are
        // recorded before the frame slot is released for reuse.
        let commitOptions = MTL4CommitOptions()
        commitOptions.addFeedbackHandler { feedback in
            submission.complete(feedbackError: feedback.error)
        }

        // Linearize the actual queue commit against feedback recording. This
        // closes the otherwise narrow race between the last health check and
        // submission: whichever acquires the error-state lock first defines the
        // observable order.
        let submitted = renderErrorState.performIfHealthy {
            resources.commandQueue.commit(
                [commandBuffer],
                options: commitOptions
            )
        }
        guard submitted else {
            frame.markAvailable()
            return
        }

        // Tell the queue which drawable belongs to the committed work, then
        // request presentation once rendering to it has completed.
        resources.commandQueue.signalDrawable(drawable)
        drawable.present()
    }

    /// Advances through the fixed-size frame resource ring.
    private func nextFrame() -> FrameResources {
        let frame = resources.frames[frameIndex]
        frameIndex = (frameIndex + 1) % resources.frames.count
        return frame
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

                // MetalKit may suballocate mesh buffers from a larger MTLBuffer, so
                // the GPU address passed to Metal 4 needs the mesh buffer's offset.
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
                        indexBuffer: indexBuffer.buffer.gpuAddress + UInt64(indexBuffer.offset),
                        indexBufferLength: indexBuffer.length
                    )
                }
            }
        }
    }

    /// Visits the exact bounded, model-resolved prefix used by visible draws.
    ///
    /// This small CPU-side seam owns draw order and missing-model filtering.
    /// Production encoding supplies the body that emits Metal commands, while
    /// integration tests can prove that a projected scene reaches every decoded
    /// model without replacing this loop with a test-only imitation.
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
    /// fragment table is complete now—its frame light was installed before the
    /// draw loop—so bind it immediately. Keeping address arithmetic and the new
    /// per-draw fragment binding in this production helper lets the offscreen
    /// GPU harness exercise the exact operation used by visible rendering.
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

    /// Resolves the same bounded instance prefix that `FrameResources` writes.
    ///
    /// Keeping truncation and resolution together prevents an off-by-one split
    /// where one material array describes a different draw than the parallel
    /// transform array. Resolution remains CPU-side and backend-private; the
    /// resulting factors are packed only after every referenced identity has
    /// succeeded.
    private func resolveMaterialDescriptions(
        for instances: [RenderInstance]
    ) throws -> [PBRMaterialDescription] {
        try instances
            .prefix(FrameResources.maximumInstanceCount)
            .map { instance in
                try resources.materialDescription(for: instance.materialID)
            }
    }

}
