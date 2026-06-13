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
import QuartzCore
import simd

@MainActor
final class MetalRenderer: NSObject, MTKViewDelegate {
    /// Keep a small ring of per-frame command allocators so the CPU can encode
    /// upcoming frames while the GPU may still be consuming earlier ones.
    static let maximumFramesInFlight = 3

    /// The drawable format must match the color attachment format baked into
    /// the render pipeline state.
    static let colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb

    /// The GPU device shared by the MetalKit view and every object this
    /// renderer creates.
    let device: any MTLDevice

    /// Fixed pipeline for this simple USD-backed renderer.
    private let renderPipelineState: any MTLRenderPipelineState

    /// Metal 4 resource binding table. Each draw updates buffer slot 0 to point
    /// at the current mesh's vertex buffer and slot 1 to point at the current
    /// render instance before encoding the draw.
    private let argumentTable: any MTL4ArgumentTable

    /// Static model loaded from USDZ through Model I/O and MetalKit.
    private let model: USDRenderModel

    /// Supplies the latest ECS-derived presentation snapshot for each draw.
    private let renderFrameProvider: @MainActor () -> RenderFrame

    /// Keeps dynamic per-frame instance buffers resident for Metal 4 queue use.
    private let frameResidencySet: any MTLResidencySet

    /// Metal 4 submits reusable command buffers through a queue instead of
    /// committing work directly from the command buffer.
    private let commandQueue: any MTL4CommandQueue

    /// Per-frame allocator ownership is tracked separately from command buffer
    /// creation because command buffers are cheap reusable recording objects,
    /// while allocators own the backing memory for encoded commands.
    private let frames: [FrameResources]

    /// Index into `frames` for the next draw call.
    private var frameIndex = 0

    init(
        device: any MTLDevice,
        renderPipelineState: any MTLRenderPipelineState,
        argumentTable: any MTL4ArgumentTable,
        model: USDRenderModel,
        renderFrameProvider: @escaping @MainActor () -> RenderFrame,
        frameResidencySet: any MTLResidencySet,
        commandQueue: any MTL4CommandQueue,
        frames: [FrameResources]
    ) {
        precondition(!frames.isEmpty, "MetalRenderer requires at least one frame resource set.")

        self.device = device
        self.renderPipelineState = renderPipelineState
        self.argumentTable = argumentTable
        self.model = model
        self.renderFrameProvider = renderFrameProvider
        self.frameResidencySet = frameResidencySet
        self.commandQueue = commandQueue
        self.frames = frames

        super.init()

        commandQueue.addResidencySet(model.residencySet)
        commandQueue.addResidencySet(frameResidencySet)
    }

    /// Registers the drawable resources that MetalKit owns so Metal 4 can keep
    /// them resident for command buffers submitted through this queue.
    func configure(_ view: MTKView) {
        commandQueue.addResidencySet(view.residencySet)

        if let layer = view.layer as? CAMetalLayer {
            commandQueue.addResidencySet(layer.residencySet)
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    /// Draws the USDZ hello triangle into the current drawable using MetalKit's
    /// Metal 4 render pass descriptor. This is still a tiny renderer, but the
    /// geometry now flows through the same Model I/O -> MetalKit path that real
    /// static mesh assets can use.
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
        commandQueue.waitForDrawable(drawable)

        // Attach this frame's allocator before encoding. A Metal 4 command
        // buffer does not own command storage until `beginCommandBuffer`.
        commandBuffer.beginCommandBuffer(allocator: frame.commandAllocator)
        let renderFrame = renderFrameProvider()
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
        draw(model, instanceCount: instanceCount, frame: frame, with: renderEncoder)

        // Ending the encoder finalizes the render pass. The pass first clears
        // the drawable using the view's clear color, then stores the triangle
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
        commandQueue.commit([commandBuffer], options: commitOptions)
        commandQueue.signalDrawable(drawable)
        drawable.present()
    }

    /// Advances through the fixed-size frame resource ring.
    private func nextFrame() -> FrameResources {
        let frame = frames[frameIndex]
        frameIndex = (frameIndex + 1) % frames.count
        return frame
    }

    private func draw(
        _ model: USDRenderModel,
        instanceCount: Int,
        frame: FrameResources,
        with renderEncoder: any MTL4RenderCommandEncoder
    ) {
        guard instanceCount > 0 else {
            return
        }

        for instanceIndex in 0..<instanceCount {
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

    /// Builds the fixed render pipeline from the app's default Metal library.
    /// Keeping this here makes the SwiftUI wrapper responsible only for view
    /// creation and device setup.
    static func makeRenderPipelineState(device: any MTLDevice) throws -> any MTLRenderPipelineState {
        guard let library = device.makeDefaultLibrary(),
              let vertexFunction = library.makeFunction(name: "modelVertex"),
              let fragmentFunction = library.makeFunction(name: "modelFragment")
        else {
            throw MetalRendererError.missingShaderFunction
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "Hello Triangle Pipeline"
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = colorPixelFormat

        return try device.makeRenderPipelineState(descriptor: descriptor)
    }

    static func makeArgumentTable(device: any MTLDevice) throws -> any MTL4ArgumentTable {
        let descriptor = MTL4ArgumentTableDescriptor()
        descriptor.label = "USD Mesh Argument Table"
        descriptor.maxBufferBindCount = 2

        return try device.makeArgumentTable(descriptor: descriptor)
    }

    static func makeFrameResources(
        device: any MTLDevice,
        count: Int = maximumFramesInFlight
    ) throws -> (frames: [FrameResources], residencySet: any MTLResidencySet) {
        let descriptor = MTLResidencySetDescriptor()
        descriptor.label = "Render Frame Buffers"
        descriptor.initialCapacity = count

        let residencySet = try device.makeResidencySet(descriptor: descriptor)
        var frames: [FrameResources] = []

        for _ in 0..<count {
            guard let commandAllocator = device.makeCommandAllocator(),
                  let instanceBuffer = device.makeBuffer(
                    length: MemoryLayout<GPUInstance>.stride * FrameResources.maximumInstanceCount,
                    options: [.storageModeShared]
                  )
            else {
                throw MetalRendererError.missingFrameResource
            }

            residencySet.addAllocation(instanceBuffer)
            frames.append(
                FrameResources(
                    commandAllocator: commandAllocator,
                    instanceBuffer: instanceBuffer
                )
            )
        }

        residencySet.commit()
        return (frames, residencySet)
    }
}

struct USDRenderModel {
    let meshes: [MTKMesh]
    let residencySet: any MTLResidencySet

    static func load(named name: String, device: any MTLDevice) throws -> USDRenderModel {
        guard let url = Bundle.main.url(forResource: name, withExtension: "usdz") else {
            throw MetalRendererError.missingModel(name)
        }

        let allocator = MTKMeshBufferAllocator(device: device)
        let vertexDescriptor = makeVertexDescriptor()
        let asset = MDLAsset(url: url, vertexDescriptor: vertexDescriptor, bufferAllocator: allocator)
        let meshes = try MTKMesh.newMeshes(asset: asset, device: device).metalKitMeshes
        let residencySet = try makeResidencySet(named: name, for: meshes, device: device)

        return USDRenderModel(meshes: meshes, residencySet: residencySet)
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

    private static func makeResidencySet(
        named name: String,
        for meshes: [MTKMesh],
        device: any MTLDevice
    ) throws -> any MTLResidencySet {
        let descriptor = MTLResidencySetDescriptor()
        descriptor.label = "\(name) USD Buffers"
        descriptor.initialCapacity = meshes.reduce(0) { count, mesh in
            count + mesh.vertexBuffers.count + mesh.submeshes.count
        }

        let residencySet = try device.makeResidencySet(descriptor: descriptor)
        var addedBuffers = Set<ObjectIdentifier>()

        for mesh in meshes {
            for vertexBuffer in mesh.vertexBuffers {
                add(vertexBuffer.buffer, to: residencySet, tracking: &addedBuffers)
            }

            for submesh in mesh.submeshes {
                add(submesh.indexBuffer.buffer, to: residencySet, tracking: &addedBuffers)
            }
        }

        residencySet.commit()
        return residencySet
    }

    private static func add(
        _ buffer: any MTLBuffer,
        to residencySet: any MTLResidencySet,
        tracking addedBuffers: inout Set<ObjectIdentifier>
    ) {
        let identifier = ObjectIdentifier(buffer as AnyObject)

        guard addedBuffers.insert(identifier).inserted else {
            return
        }

        residencySet.addAllocation(buffer)
    }
}

private struct GPUInstance {
    var modelViewProjectionMatrix: simd_float4x4

    init(_ instance: RenderInstance, viewProjectionMatrix: simd_float4x4) {
        modelViewProjectionMatrix = viewProjectionMatrix * instance.transform.matrix
    }
}

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
    func markAvailable() {
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
    case missingShaderFunction
    case missingModel(String)
    case missingFrameResource
}
