//
//  MetalRenderer.swift
//  Engine2
//
//  Created by Codex on 5/25/26.
//

import Dispatch
import Metal
import MetalKit
import QuartzCore

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

    /// Fixed pipeline for the first renderer milestone: one vertex shader, one
    /// fragment shader, and no external resources.
    private let renderPipelineState: any MTLRenderPipelineState

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
        commandQueue: any MTL4CommandQueue,
        commandAllocators: [any MTL4CommandAllocator]
    ) {
        precondition(!commandAllocators.isEmpty, "MetalRenderer requires at least one command allocator.")

        self.device = device
        self.renderPipelineState = renderPipelineState
        self.commandQueue = commandQueue
        self.frames = commandAllocators.map(FrameResources.init(commandAllocator:))

        super.init()
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

    /// Draws a hard-coded triangle into the current drawable using MetalKit's
    /// Metal 4 render pass descriptor. This is the smallest useful rendering
    /// milestone: a real pipeline and draw call, but no engine-driven
    /// presentation state yet.
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

        // The shader creates positions and colors from `vertex_id`, so this
        // first triangle does not need a vertex buffer or argument table.
        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.drawPrimitives(primitiveType: .triangle, vertexStart: 0, vertexCount: 3)

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

    /// Builds the fixed render pipeline from the app's default Metal library.
    /// Keeping this here makes the SwiftUI wrapper responsible only for view
    /// creation and device setup.
    static func makeRenderPipelineState(device: any MTLDevice) throws -> any MTLRenderPipelineState {
        guard let library = device.makeDefaultLibrary(),
              let vertexFunction = library.makeFunction(name: "helloTriangleVertex"),
              let fragmentFunction = library.makeFunction(name: "helloTriangleFragment")
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
}

private final class FrameResources: @unchecked Sendable {
    /// The allocator that backs command encoding for one frame slot.
    let commandAllocator: any MTL4CommandAllocator

    /// Starts available. A draw call waits on it before reusing the allocator,
    /// and the queue feedback handler signals it after GPU completion.
    private let availability = DispatchSemaphore(value: 1)

    init(commandAllocator: any MTL4CommandAllocator) {
        self.commandAllocator = commandAllocator
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
}

private enum MetalRendererError: Error {
    case missingShaderFunction
}
