import Foundation
import Metal
import MetalKit
import ModelIO
import simd

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

    /// Unlit surface pipeline used while material shading is bootstrapped.
    private let surfacePipelineState: any MTLRenderPipelineState

    /// Diagnostic pipeline that maps interpolated view-space normals to color.
    private let normalDiagnosticPipelineState: any MTLRenderPipelineState

    /// Opaque depth behavior shared by the surface and normal diagnostic views.
    private let depthStencilState: any MTLDepthStencilState

    /// Metal 4 resource binding table. Each draw updates buffer slot 0 to point
    /// at the current mesh's vertex buffer and slot 1 to point at the current
    /// render instance before encoding the draw.
    private let argumentTable: any MTL4ArgumentTable

    /// Read-only Simulation Runtime publication selected at render cadence.
    /// The App owns the source's lifetime; Render does not retain its peer runtime.
    weak var presentationSource: (any PSimulationPresentationSource)?

    /// Selects the visible output without changing geometry, transforms, depth,
    /// or draw submission. Debug tooling can switch this value at render cadence.
    var outputMode: RenderOutputMode

    /// Index into `frames` for the next draw call.
    private var frameIndex = 0

    init(
        resources: MetalResourceStore,
        presentationSource: any PSimulationPresentationSource,
        outputMode: RenderOutputMode = .surface
    ) throws {
        precondition(
            !resources.frames.isEmpty,
            "MetalRenderer requires at least one frame resource set."
        )

        self.resources = resources
        self.surfacePipelineState = try resources.renderPipelineState(for: .modelSurface)
        self.normalDiagnosticPipelineState = try resources.renderPipelineState(
            for: .modelNormalDiagnostic
        )
        self.depthStencilState = try resources.depthStencilState(for: .opaque)
        self.argumentTable = try resources.argumentTable(for: .model)
        self.presentationSource = presentationSource
        self.outputMode = outputMode

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
    }

    /// Configures renderer-owned attachment policy and registers MetalKit-owned
    /// drawable resources for explicit Metal 4 queue residency.
    func configure(_ view: MTKView) {
        Self.configureRenderTargets(on: view)
        resources.residency.registerExternalResources(for: view)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    /// Draws the models selected by the latest immutable render frame.
    func draw(in view: MTKView) {
        // Pick the next frame slot before touching the drawable. If all slots
        // are still in flight, this applies back pressure here instead of
        // continuing to allocate command memory without bound.
        let frame = nextFrame()
        frame.waitUntilAvailable()

        // The commit feedback handler marks the frame available only after the
        // GPU finishes the previous workload that used this allocator, so it is
        // safe to recycle the allocator's internal command memory now.
        frame.commandAllocator.reset()

        // Ask MetalKit for the drawable and the Metal 4 render pass descriptor
        // as late as possible. Holding drawable references longer than needed
        // can reduce how much buffering Core Animation has available.
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentMTL4RenderPassDescriptor,
              let commandBuffer = device.makeCommandBuffer()
        else {
            // No GPU work was submitted for this slot, so release it back to the
            // ring immediately.
            frame.markAvailable()
            return
        }

        // Drawable ownership is explicit in Metal 4: wait before encoding work
        // that targets it, then signal when submitted work has completed.
        resources.commandQueue.waitForDrawable(drawable)

        // Attach this frame's allocator before encoding. A Metal 4 command
        // buffer does not own command storage until `beginCommandBuffer`.
        commandBuffer.beginCommandBuffer(allocator: frame.commandAllocator)
        let renderFrame: RenderFrame
        if let presentationSource {
            renderFrame = RenderFrame.project(
                from: presentationSource.latestPresentationSnapshot
            )
        } else {
            renderFrame = .empty
        }
        let instanceCount = frame.write(
            renderFrame.instances,
            camera: renderFrame.camera,
            drawableSize: view.drawableSize
        )

        // The descriptor already contains the current drawable texture and the
        // clear color configured on `MTKView`. The pipeline state tells Metal
        // which compiled shader functions and color format this pass uses.
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(
            descriptor: renderPassDescriptor,
            options: []
        ) else {
            // Close the command buffer cleanly even though no work will be
            // submitted, then release the frame slot for the next draw.
            commandBuffer.endCommandBuffer()
            frame.markAvailable()
            return
        }

        renderEncoder.setRenderPipelineState(renderPipelineState(for: outputMode))
        renderEncoder.setDepthStencilState(depthStencilState)
        draw(
            renderFrame.instances,
            instanceCount: instanceCount,
            frame: frame,
            with: renderEncoder
        )

        // Ending the encoder finalizes the render pass. The pass first clears
        // the drawable using the view's clear color, then stores the model
        // color output into the drawable texture.
        renderEncoder.endEncoding()

        // `endCommandBuffer` makes the recorded work valid for queue submission.
        commandBuffer.endCommandBuffer()

        // Metal 4 residency is not object ownership. Retain the complete store,
        // the drawable, and this pass's view-owned depth texture independently
        // of the SwiftUI coordinator until queue feedback reports completion.
        let submission = MetalInFlightSubmission(
            resources: resources,
            drawable: drawable,
            depthTexture: renderPassDescriptor.depthAttachment.texture,
            frame: frame
        )

        // Feedback is the point where this simple renderer learns the GPU is
        // done with the frame's command allocator and referenced resources. A
        // fuller renderer would also inspect `feedback.error` here and surface
        // device failures.
        let commitOptions = MTL4CommitOptions()
        commitOptions.addFeedbackHandler { _ in
            submission.complete()
        }

        // Submit the recorded work first, then tell the queue which drawable is
        // associated with that work. `present()` requests display once the queue
        // has completed rendering to the drawable.
        resources.commandQueue.commit([commandBuffer], options: commitOptions)
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
            surfacePipelineState

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

        for instanceIndex in 0..<instanceCount {
            // Missing catalog entries make only the affected instance
            // unrenderable; they do not invalidate the rest of the frame.
            guard let model = resources.model(
                for: instances[instanceIndex].meshID
            ) else {
                continue
            }

            argumentTable.setAddress(
                frame.instanceBuffer.gpuAddress + UInt64(instanceIndex * MemoryLayout<GPUInstance>.stride),
                index: 1
            )

            for mesh in model.meshes {
                guard let vertexBuffer = mesh.vertexBuffers.first else {
                    continue
                }

                // MetalKit may suballocate mesh buffers from a larger MTLBuffer, so
                // the GPU address passed to Metal 4 needs the mesh buffer's offset.
                argumentTable.setAddress(
                    vertexBuffer.buffer.gpuAddress + UInt64(vertexBuffer.offset),
                    index: 0
                )
                renderEncoder.setArgumentTable(argumentTable, stages: .vertex)

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

}

/// Renderer-owned decoded mesh data for one packaged USD model.
///
/// The value groups MetalKit meshes and exposes the unique allocations needed
/// for explicit Metal 4 residency. Game Content supplies only the abstract
/// asset reference and never receives these backend objects.
struct USDRenderModel {
    let meshes: [MTKMesh]

    /// Unique Metal allocations retained by this decoded model. The resource
    /// store decides which residency set owns their residency lifetime.
    var allocations: [any MTLAllocation] {
        var allocations: [any MTLAllocation] = []
        var addedAllocations = Set<ObjectIdentifier>()

        for mesh in meshes {
            for vertexBuffer in mesh.vertexBuffers {
                append(
                    vertexBuffer.buffer,
                    to: &allocations,
                    tracking: &addedAllocations
                )
            }

            for submesh in mesh.submeshes {
                append(
                    submesh.indexBuffer.buffer,
                    to: &allocations,
                    tracking: &addedAllocations
                )
            }
        }

        return allocations
    }

    /// Resolves every Game Content model reference into renderer-owned Metal
    /// resources. The catalog itself never receives those backend objects.
    static func load(
        catalog: RenderAssetCatalog,
        device: any MTLDevice
    ) throws -> [MeshID: USDRenderModel] {
        var models: [MeshID: USDRenderModel] = [:]

        for (meshID, asset) in catalog.models {
            models[meshID] = try load(asset, device: device)
        }

        return models
    }

    private static func load(
        _ modelAsset: ModelAssetReference,
        device: any MTLDevice
    ) throws -> USDRenderModel {
        guard let url = Bundle.main.url(
            forResource: modelAsset.resourceName,
            withExtension: modelAsset.format.rawValue
        ) else {
            throw MetalRendererError.missingModel(modelAsset.resourceName)
        }

        let allocator = MTKMeshBufferAllocator(device: device)
        let vertexDescriptor = makeVertexDescriptor()
        let modelIOAsset = MDLAsset(
            url: url,
            vertexDescriptor: vertexDescriptor,
            bufferAllocator: allocator
        )
        let meshes = try MTKMesh.newMeshes(
            asset: modelIOAsset,
            device: device
        ).metalKitMeshes
        return USDRenderModel(meshes: meshes)
    }

    /// Defines the one interleaved vertex layout shared by Model I/O and Metal.
    ///
    /// `SIMD3<Float>` has a 16-byte stride on both sides of this boundary, so
    /// explicit offsets keep the Swift descriptor aligned with `ModelVertex` in
    /// `ModelShaders.metal`. Vertex color remains only as the pre-material visual
    /// baseline. The packaged asset is an implicit USD sphere, so requesting a
    /// normal attribute lets Model I/O's USD importer supply its generated
    /// sphere normals without introducing an engine-wide generation policy.
    static func makeVertexDescriptor() -> MDLVertexDescriptor {
        let vertexDescriptor = MDLVertexDescriptor()
        vertexDescriptor.attributes[0] = MDLVertexAttribute(
            name: MDLVertexAttributePosition,
            format: .float3,
            offset: 0,
            bufferIndex: 0
        )
        vertexDescriptor.attributes[1] = MDLVertexAttribute(
            name: MDLVertexAttributeColor,
            format: .float3,
            offset: MemoryLayout<SIMD3<Float>>.stride,
            bufferIndex: 0
        )
        vertexDescriptor.attributes[2] = MDLVertexAttribute(
            name: MDLVertexAttributeNormal,
            format: .float3,
            offset: MemoryLayout<SIMD3<Float>>.stride * 2,
            bufferIndex: 0
        )
        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(
            stride: MemoryLayout<SIMD3<Float>>.stride * 3
        )

        return vertexDescriptor
    }

    private func append(
        _ allocation: any MTLAllocation,
        to allocations: inout [any MTLAllocation],
        tracking addedAllocations: inout Set<ObjectIdentifier>
    ) {
        let identifier = ObjectIdentifier(allocation as AnyObject)

        guard addedAllocations.insert(identifier).inserted else {
            return
        }

        allocations.append(allocation)
    }
}

/// CPU-side layout written to the per-frame GPU instance buffer.
///
/// Its fields match `ModelInstance` in `ModelShaders.metal`. The shader needs a
/// complete clip transform for rasterization, a model-view transform for future
/// view-space lighting, and an inverse-transpose linear transform so nonuniform
/// entity scale cannot skew surface normals.
struct GPUInstance {
    var modelViewProjectionMatrix: simd_float4x4
    var modelViewMatrix: simd_float4x4
    var normalMatrix: simd_float3x3

    init(
        _ instance: RenderInstance,
        viewMatrix: simd_float4x4,
        projectionMatrix: simd_float4x4
    ) {
        // Build model-view once so the position and normal paths use exactly the
        // same model and camera transforms.
        precondition(
            instance.transform.supportsNormalTransform,
            "GPU instances require a finite transform with invertible scale."
        )
        let modelViewMatrix = viewMatrix * instance.transform.matrix
        precondition(
            modelViewMatrix.hasFiniteElements,
            "GPU instances require a finite model-view transform."
        )
        let linearModelView = simd_float3x3(
            columns: (
                SIMD3<Float>(
                    modelViewMatrix.columns.0.x,
                    modelViewMatrix.columns.0.y,
                    modelViewMatrix.columns.0.z
                ),
                SIMD3<Float>(
                    modelViewMatrix.columns.1.x,
                    modelViewMatrix.columns.1.y,
                    modelViewMatrix.columns.1.z
                ),
                SIMD3<Float>(
                    modelViewMatrix.columns.2.x,
                    modelViewMatrix.columns.2.y,
                    modelViewMatrix.columns.2.z
                )
            )
        )
        let linearDeterminant = simd_determinant(linearModelView)
        precondition(
            linearDeterminant.isFinite && linearDeterminant != 0,
            "GPU instances require a finite, invertible model-view transform."
        )

        self.modelViewProjectionMatrix = projectionMatrix * modelViewMatrix
        self.modelViewMatrix = modelViewMatrix
        self.normalMatrix = simd_transpose(simd_inverse(linearModelView))
    }
}

/// Internal asset-resolution failures surfaced while constructing render resources.
private enum MetalRendererError: Error {
    case missingModel(String)
}
