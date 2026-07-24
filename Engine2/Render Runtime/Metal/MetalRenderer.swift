import CoreGraphics
import Foundation
import Metal
import MetalKit

/// MetalKit adapter that presents the latest completed render frame onscreen.
///
/// `MetalRenderer` samples a narrow presentation source at render cadence,
/// projects it into private `RenderFrame` data, and delegates reusable GPU work
/// to a view-independent ``MetalFrameEncoder``. It retains drawable cadence,
/// queue submission, presentation, and screen error policy. It never reads live
/// ECS storage or controls the Simulation Runtime lifecycle.
@MainActor
final class MetalRenderer: NSObject, MTKViewDelegate {
    /// Device-scoped owner for every backend object used by this renderer.
    let resources: MetalResourceStore

    /// The MetalKit view must use the same device as the resource store.
    var device: any MTLDevice {
        resources.device
    }

    /// View-independent owner of reusable Metal frame preparation and encoding.
    private let frameEncoder: MetalFrameEncoder

    /// Terminal preparation and asynchronous queue failures are preserved
    /// across frame callbacks. Once one is observed, this renderer stops
    /// submitting additional GPU work; diagnostics can still inspect the
    /// latest failure from work already live.
    private let renderErrorState = MetalRenderErrorState()

    /// Read-only Simulation Runtime publication selected at render cadence.
    /// The App owns the source's lifetime; Render does not retain its peer runtime.
    weak var presentationSource: (any PSimulationPresentationSource)?

    /// Read-only output-specific viewpoint selected by the App assembly.
    ///
    /// The source resolves against Simulation's published camera as a default;
    /// Render never interprets raw input or mutates authoritative camera state.
    weak var viewpointSource: (any PRenderViewpointSource)?

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
        viewpointSource: (any PRenderViewpointSource)? = nil,
        outputMode: RenderOutputMode = .surface
    ) throws {
        precondition(
            !resources.frames.isEmpty,
            "MetalRenderer requires at least one frame resource set."
        )

        self.resources = resources
        self.frameEncoder = try MetalFrameEncoder(resources: resources)
        self.presentationSource = presentationSource
        self.viewpointSource = viewpointSource
        self.outputMode = outputMode

        super.init()
    }

    /// Configures renderer-owned attachment policy and registers MetalKit-owned
    /// drawable resources for explicit Metal 4 queue residency.
    func configure(_ view: MTKView) {
        view.colorPixelFormat = MetalFrameEncoder.destinationColorPixelFormat
        view.depthStencilPixelFormat = MetalFrameEncoder.depthPixelFormat
        view.clearDepth = MetalFrameEncoder.clearDepth

        // Fragment shaders return display-linear values. Declaring the view's
        // presentation color space and using an `_srgb` drawable makes the
        // drawable perform the one and only linear-to-sRGB transfer.
        view.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
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
            let snapshot = presentationSource.latestPresentationSnapshot
            let viewpoint = viewpointSource?.resolveViewpoint(
                defaultCamera: snapshot.camera
            )
            renderFrame = RenderFrame(
                projecting: snapshot,
                viewpoint: viewpoint
            )
        } else {
            renderFrame = .empty
        }

        let preparedFrame = frameEncoder.prepare(renderFrame)

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

        // Phase one shades opaque geometry into linear half-float scene color;
        // phase two presents that stored value to the sRGB drawable. The frame
        // encoder owns their shared buffer packing, draws, barrier, and ordering.
        do {
            try frameEncoder.encode(
                preparedFrame,
                inputs: MetalFrameEncodingInputs(
                    frameResources: frame,
                    sceneColorTexture: sceneTarget.texture,
                    depthTexture: depthTexture,
                    destinationTexture: drawable.texture,
                    clearColor: viewRenderPassDescriptor
                        .colorAttachments[0].clearColor,
                    outputMode: outputMode
                ),
                into: commandBuffer
            )
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
}
