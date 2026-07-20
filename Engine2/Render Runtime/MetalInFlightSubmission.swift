import Metal
import QuartzCore

/// Retains every owner whose Metal objects are referenced by one submission.
///
/// Metal 4 residency makes allocations available to the GPU, but it does not
/// retain their Swift objects. A submission can outlive `MetalSceneView` and
/// its coordinator during SwiftUI teardown, so the completion callback keeps
/// this token alive until the GPU has finished. The token, in turn, retains the
/// renderer's resource store, the exact drawable, the exact depth attachment,
/// and the frame slot whose command storage and instance buffer were encoded.
final class MetalInFlightSubmission: @unchecked Sendable {
    private let resources: MetalResourceStore
    private let drawable: any CAMetalDrawable
    private let depthTexture: (any MTLTexture)?
    private let frame: FrameResources

    @MainActor
    init(
        resources: MetalResourceStore,
        drawable: any CAMetalDrawable,
        depthTexture: (any MTLTexture)?,
        frame: FrameResources
    ) {
        self.resources = resources
        self.drawable = drawable
        self.depthTexture = depthTexture
        self.frame = frame
    }

    /// Releases the frame slot after the queue reports GPU completion.
    ///
    /// The callback may arrive away from the main actor. `FrameResources` owns
    /// the thread-safe semaphore operation; releasing this token after the call
    /// also releases the retained Metal object graph.
    nonisolated func complete() {
        frame.markAvailable()
    }
}
