import Dispatch
import Metal
@testable import Engine2

/// Retains an offscreen test submission independently of its timeout waiter.
///
/// A timeout reports a test failure but does not prove the GPU has stopped
/// referencing Metal 4 resources. Queue feedback captures this token, keeping
/// the store and every transient attachment and buffer alive until actual GPU
/// completion even if the test function has already returned.
final class MetalOffscreenTestSubmission: @unchecked Sendable {
    private let resources: MetalResourceStore
    private let colorTexture: any MTLTexture
    private let depthTexture: any MTLTexture
    private let nearVertexBuffer: any MTLBuffer
    private let farVertexBuffer: any MTLBuffer
    private let completion: DispatchSemaphore

    @MainActor
    init(
        resources: MetalResourceStore,
        colorTexture: any MTLTexture,
        depthTexture: any MTLTexture,
        nearVertexBuffer: any MTLBuffer,
        farVertexBuffer: any MTLBuffer,
        completion: DispatchSemaphore
    ) {
        self.resources = resources
        self.colorTexture = colorTexture
        self.depthTexture = depthTexture
        self.nearVertexBuffer = nearVertexBuffer
        self.farVertexBuffer = farVertexBuffer
        self.completion = completion
    }

    /// Signals the waiter while this token still owns all submitted resources.
    nonisolated func complete() {
        completion.signal()
    }
}
