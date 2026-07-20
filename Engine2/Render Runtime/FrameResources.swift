import CoreGraphics
import Dispatch
import Metal

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

    init(
        commandAllocator: any MTL4CommandAllocator,
        instanceBuffer: any MTLBuffer
    ) {
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
        let aspectRatio = Float(
            drawableSize.width / max(drawableSize.height, 1)
        )
        let viewMatrix = camera.viewMatrix
        let projectionMatrix = camera.projectionMatrix(
            aspectRatio: aspectRatio
        )
        let destination = instanceBuffer.contents().bindMemory(
            to: GPUInstance.self,
            capacity: Self.maximumInstanceCount
        )

        for index in 0..<instanceCount {
            destination[index] = GPUInstance(
                instances[index],
                viewMatrix: viewMatrix,
                projectionMatrix: projectionMatrix
            )
        }

        return instanceCount
    }
}
