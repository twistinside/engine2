//
//  MetalRenderer.swift
//  Engine2
//
//  Created by Codex on 5/25/26.
//

import Dispatch
import Foundation
import Metal
import MetalKit
import ModelIO
import simd

@MainActor
final class MetalRenderer: NSObject, MTKViewDelegate {
    /// Keep a small ring of per-frame command allocators so the CPU can encode
    /// upcoming frames while the GPU may still be consuming earlier ones.
    static let maximumFramesInFlight = 3

    /// The drawable format must match the color attachment format baked into
    /// the render pipeline state.
    static let colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb

    /// Device-scoped owner for every backend object used by this renderer.
    let resources: MetalResourceStore

    /// The MetalKit view must use the same device as the resource store.
    var device: any MTLDevice {
        resources.device
    }

    /// Fixed pipeline for this simple USD-backed renderer.
    private let renderPipelineState: any MTLRenderPipelineState

    /// Explicit depth behavior, even while the current view has no depth
    /// attachment. Future pipelines can select a different cached state.
    private let depthStencilState: any MTLDepthStencilState

    /// Metal 4 resource binding table. Each draw updates buffer slot 0 to point
    /// at the current mesh's vertex buffer and slot 1 to point at the current
    /// render instance before encoding the draw.
    private let argumentTable: any MTL4ArgumentTable

    /// Read-only Simulation Runtime publication selected at render cadence.
    /// The App owns the source's lifetime; Render does not retain its peer runtime.
    weak var presentationSource: (any PSimulationPresentationSource)?

    /// Index into `frames` for the next draw call.
    private var frameIndex = 0

    init(
        resources: MetalResourceStore,
        presentationSource: any PSimulationPresentationSource
    ) throws {
        precondition(
            !resources.frames.isEmpty,
            "MetalRenderer requires at least one frame resource set."
        )

        self.resources = resources
        self.renderPipelineState = try resources.renderPipelineState(for: .model)
        self.depthStencilState = try resources.depthStencilState(for: .disabled)
        self.argumentTable = try resources.argumentTable(for: .model)
        self.presentationSource = presentationSource

        super.init()
    }

    /// Registers the drawable resources that MetalKit owns so Metal 4 can keep
    /// them resident for command buffers submitted through this queue.
    func configure(_ view: MTKView) {
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

        renderEncoder.setRenderPipelineState(renderPipelineState)
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

        // Feedback is the point where this simple renderer learns the GPU is
        // done with the frame's command allocator. A fuller renderer would also
        // inspect `feedback.error` here and surface device failures.
        let commitOptions = MTL4CommitOptions()
        commitOptions.addFeedbackHandler { _ in
            frame.markAvailable()
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

    private static func makeVertexDescriptor() -> MDLVertexDescriptor {
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
        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<SIMD3<Float>>.stride * 2)

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

struct GPUInstance {
    var modelViewProjectionMatrix: simd_float4x4

    init(_ instance: RenderInstance, viewProjectionMatrix: simd_float4x4) {
        modelViewProjectionMatrix = viewProjectionMatrix * instance.transform.matrix
    }
}

/// Resources encoded on the main actor and released by Metal completion
/// callbacks. The semaphore protects slot availability across those contexts.
final class FrameResources: @unchecked Sendable {
    static let maximumInstanceCount = 256

    /// The allocator that backs command encoding for one frame slot.
    let commandAllocator: any MTL4CommandAllocator

    /// CPU-written, GPU-read transform data for entities in the current frame.
    let instanceBuffer: any MTLBuffer

    /// Starts available. A draw call waits on it before reusing the allocator,
    /// and the queue feedback handler signals it after GPU completion.
    private let availability = DispatchSemaphore(value: 1)

    init(commandAllocator: any MTL4CommandAllocator, instanceBuffer: any MTLBuffer) {
        self.commandAllocator = commandAllocator
        self.instanceBuffer = instanceBuffer
    }

    /// Blocks the main actor only when the CPU outruns all in-flight frame
    /// slots. With three slots, this should happen only under sustained GPU
    /// pressure.
    func waitUntilAvailable() {
        availability.wait()
    }

    /// Releases this frame slot for reuse by a later draw call.
    nonisolated func markAvailable() {
        availability.signal()
    }

    func write(
        _ instances: [RenderInstance],
        camera: Camera,
        drawableSize: CGSize
    ) -> Int {
        let instanceCount = min(instances.count, Self.maximumInstanceCount)
        let aspectRatio = Float(drawableSize.width / max(drawableSize.height, 1))
        let viewProjectionMatrix = camera.viewProjectionMatrix(aspectRatio: aspectRatio)
        let destination = instanceBuffer.contents().bindMemory(
            to: GPUInstance.self,
            capacity: Self.maximumInstanceCount
        )

        for index in 0..<instanceCount {
            destination[index] = GPUInstance(
                instances[index],
                viewProjectionMatrix: viewProjectionMatrix
            )
        }

        return instanceCount
    }
}

private enum MetalRendererError: Error {
    case missingModel(String)
}
