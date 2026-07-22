import Foundation
import Metal

/// Retains every owner referenced by one submitted Metal offscreen render.
///
/// Metal 4 residency controls allocation visibility but does not retain the
/// Swift object graph. The queue feedback closure retains this token, which in
/// turn keeps the exact store, encoder, frame slot, command buffer, HDR target,
/// and request targets alive until GPU completion. Its lock makes duplicate
/// feedback harmless and protects the one-shot checked continuation.
nonisolated final class MetalOffscreenSubmission: @unchecked Sendable {
    private let resources: MetalResourceStore
    private let encoder: MetalFrameEncoder
    private let frame: FrameResources
    private let commandBuffer: any MTL4CommandBuffer
    private let sceneTarget: MetalHDRSceneTarget
    private let targets: MetalOffscreenRenderTargets

    private let stateLock = NSLock()
    private var continuation: CheckedContinuation<
        MetalOffscreenCompletion,
        Never
    >?

    /// Captures the complete submitted object graph and its awaiting caller.
    @MainActor
    init(
        resources: MetalResourceStore,
        encoder: MetalFrameEncoder,
        frame: FrameResources,
        commandBuffer: any MTL4CommandBuffer,
        sceneTarget: MetalHDRSceneTarget,
        targets: MetalOffscreenRenderTargets,
        continuation: CheckedContinuation<MetalOffscreenCompletion, Never>
    ) {
        self.resources = resources
        self.encoder = encoder
        self.frame = frame
        self.commandBuffer = commandBuffer
        self.sceneTarget = sceneTarget
        self.targets = targets
        self.continuation = continuation
    }

    /// Releases the frame slot and resumes the caller exactly once.
    ///
    /// Feedback can arrive away from the main actor. The frame's semaphore is
    /// thread-safe, and it is signaled before resumption so any completed result
    /// never races a later request for the sole offscreen frame slot.
    nonisolated func complete(feedbackError: (any Error)?) {
        let completion: MetalOffscreenCompletion
        if let feedbackError {
            completion = .failure(String(describing: feedbackError))
        } else {
            completion = .success
        }

        stateLock.lock()
        guard let continuation else {
            stateLock.unlock()
            return
        }
        self.continuation = nil
        stateLock.unlock()

        frame.markAvailable()
        continuation.resume(returning: completion)
    }
}
