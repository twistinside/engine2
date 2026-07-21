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

    /// Writes the bounded instance prefix and its already-resolved materials.
    ///
    /// `materialDescriptions` must preserve the order of `instances` and cover
    /// every element that fits in this slot. Keeping resolution outside this
    /// method lets missing authored content fail before mutable GPU state is
    /// touched, while this method remains responsible only for stable packing.
    func write(
        _ instances: [RenderInstance],
        materialDescriptions: [PBRMaterialDescription],
        camera: Camera,
        drawableSize: CGSize,
        exposure: ManualExposure = .validation
    ) -> Int {
        let instanceCount = min(instances.count, Self.maximumInstanceCount)
        precondition(
            materialDescriptions.count == instanceCount,
            "Frame resources require exactly one resolved material description for every written instance."
        )
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
            // Material resolution preserves the submitted instance prefix and
            // happens before this write. Keep those parallel values aligned so
            // each stable GPU record contains the factors for its exact draw.
            destination[index] = GPUInstance(
                instances[index],
                material: materialDescriptions[index],
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

        return instanceCount
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
