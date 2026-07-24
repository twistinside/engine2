import CoreGraphics
import Dispatch
import Metal

/// Resources encoded on the main actor and released by Metal completion
/// callbacks. The semaphore protects slot availability across those contexts.
final class FrameResources: @unchecked Sendable {
    static let maximumInstanceCount = 256

    /// The allocator that backs command encoding for one frame slot.
    let commandAllocator: any MTL4CommandAllocator

    /// CPU-written, GPU-read transform and material data for current draws.
    let instanceBuffer: any MTLBuffer

    /// Renderer-owned validation directional-light parameters.
    let pbrSceneParametersBuffer: any MTLBuffer

    /// Manual exposure consumed by the surface presentation pipeline.
    let hdrPresentationParametersBuffer: any MTLBuffer

    /// Lazily sized scene target for this exact reusable frame slot.
    private(set) var hdrSceneTarget: MetalHDRSceneTarget?

    /// Starts available. A draw call waits on it before reusing the allocator,
    /// and the queue feedback handler signals it after GPU completion.
    private let availability = DispatchSemaphore(value: 1)

    init(
        commandAllocator: any MTL4CommandAllocator,
        instanceBuffer: any MTLBuffer,
        pbrSceneParametersBuffer: any MTLBuffer,
        hdrPresentationParametersBuffer: any MTLBuffer
    ) {
        self.commandAllocator = commandAllocator
        self.instanceBuffer = instanceBuffer
        self.pbrSceneParametersBuffer = pbrSceneParametersBuffer
        self.hdrPresentationParametersBuffer = hdrPresentationParametersBuffer
        self.hdrSceneTarget = nil
    }

    /// Blocks the main actor only when the CPU outruns all in-flight frame
    /// slots. With three slots, this should happen only under sustained GPU
    /// pressure.
    nonisolated func waitUntilAvailable() {
        availability.wait()
    }

    /// Releases this frame slot for reuse by a later draw call.
    nonisolated func markAvailable() {
        availability.signal()
    }

    /// Writes the exact already-bounded and resource-resolved instance set.
    ///
    /// Keeping resolution outside this method lets content preparation finish
    /// before mutable GPU state is touched, while this method remains
    /// responsible only for stable packing.
    func write(
        _ preparedFrame: MetalPreparedFrame,
        drawableSize: CGSize,
        exposure: ManualExposure = .validation
    ) {
        precondition(
            preparedFrame.instances.count <= Self.maximumInstanceCount,
            "Prepared frames must fit the reusable instance buffer."
        )
        let camera = preparedFrame.renderFrame.camera
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

        for (index, instance) in preparedFrame.instances.enumerated() {
            destination[index] = GPUInstance(
                instance.renderInstance,
                material: instance.materialDescription,
                viewMatrix: viewMatrix,
                projectionMatrix: projectionMatrix
            )
        }

        // Invalid published cameras project to an empty RenderFrame. Keep the
        // unused parameter buffer finite in that case so GPU inspection never
        // encounters stale NaNs; any nonempty frame has already validated its
        // actual camera at the Render projection boundary.
        let parameterCamera = camera.supportsViewTransform ? camera : Camera()
        pbrSceneParametersBuffer.contents().storeBytes(
            of: PBRSceneParameters(camera: parameterCamera),
            as: PBRSceneParameters.self
        )
        hdrPresentationParametersBuffer.contents().storeBytes(
            of: HDRPresentationParameters(exposure: exposure),
            as: HDRPresentationParameters.self
        )
    }

    /// Binds one written instance record to both model shader stages.
    ///
    /// The vertex table is rebound after the caller selects a mesh address. The
    /// PBR fragment table is complete when this method binds it because frame
    /// light state is installed before the draw loop.
    func bindInstance(
        at index: Int,
        modelArgumentTable: any MTL4ArgumentTable,
        pbrSceneArgumentTable: any MTL4ArgumentTable,
        to renderEncoder: any MTL4RenderCommandEncoder
    ) {
        precondition(
            (0..<Self.maximumInstanceCount).contains(index),
            "Model instance selection must remain inside the frame buffer."
        )

        let instanceAddress = instanceBuffer.gpuAddress
            + UInt64(index * MemoryLayout<GPUInstance>.stride)
        modelArgumentTable.setAddress(instanceAddress, index: 1)
        pbrSceneArgumentTable.setAddress(instanceAddress, index: 1)
        renderEncoder.setArgumentTable(
            pbrSceneArgumentTable,
            stages: .fragment
        )
    }

    /// Returns a scene target matching the next drawable's exact pixel size.
    ///
    /// Callers must own this frame slot by waiting for availability first.
    /// That invariant makes it safe to release a differently sized previous
    /// target: no submitted command can still reference this slot's resources.
    func prepareHDRSceneTarget(
        device: any MTLDevice,
        width: Int,
        height: Int
    ) throws -> MetalHDRSceneTarget {
        if let hdrSceneTarget,
           hdrSceneTarget.matches(width: width, height: height) {
            return hdrSceneTarget
        }

        let replacement = try MetalHDRSceneTarget(
            device: device,
            width: width,
            height: height
        )
        hdrSceneTarget = replacement
        return replacement
    }
}
