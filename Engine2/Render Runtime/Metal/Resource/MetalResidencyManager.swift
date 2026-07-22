import Metal
import MetalKit
import QuartzCore

/// Owns the Metal 4 residency sets used by one Render Runtime.
///
/// Metal 4 command buffers do not retain or implicitly make every referenced
/// allocation resident. The resource store retains the actual objects, while
/// this manager groups their `MTLAllocation`s by lifetime and registers those
/// groups with the command queue.
@MainActor
final class MetalResidencyManager {
    /// Immutable meshes, textures, and other long-lived content allocations.
    let staticAssets: any MTLResidencySet

    /// Buffers reused by the fixed frame-resource ring.
    let frameResources: any MTLResidencySet

    private let commandQueue: any MTL4CommandQueue
    private var registeredExternalSets: Set<ObjectIdentifier> = []

    init(
        device: any MTLDevice,
        commandQueue: any MTL4CommandQueue,
        staticAssetCapacity: Int,
        frameResourceCapacity: Int
    ) throws {
        let staticDescriptor = MTLResidencySetDescriptor()
        staticDescriptor.label = "Static Render Assets"
        staticDescriptor.initialCapacity = staticAssetCapacity

        let frameDescriptor = MTLResidencySetDescriptor()
        frameDescriptor.label = "Render Frame Buffers"
        frameDescriptor.initialCapacity = frameResourceCapacity

        self.staticAssets = try device.makeResidencySet(
            descriptor: staticDescriptor
        )
        self.frameResources = try device.makeResidencySet(
            descriptor: frameDescriptor
        )
        self.commandQueue = commandQueue

        // Queue-level registration applies these sets to every submitted
        // command buffer, matching their Render Runtime-wide lifetimes.
        commandQueue.addResidencySet(staticAssets)
        commandQueue.addResidencySet(frameResources)
    }

    /// Adds a long-lived allocation if it is not already in the static set.
    func addStaticAllocation(_ allocation: any MTLAllocation) {
        guard !staticAssets.containsAllocation(allocation) else {
            return
        }

        staticAssets.addAllocation(allocation)
    }

    /// Adds a per-frame allocation if it is not already in the frame set.
    func addFrameAllocation(_ allocation: any MTLAllocation) {
        guard !frameResources.containsAllocation(allocation) else {
            return
        }

        frameResources.addAllocation(allocation)
    }

    /// Applies all pending static allocation changes in one residency update.
    func commitStaticAssets() {
        staticAssets.commit()
    }

    /// Applies all pending frame allocation changes in one residency update.
    func commitFrameResources() {
        frameResources.commit()
    }

    /// Registers MetalKit and Core Animation allocations owned outside the
    /// resource store. Their own residency sets remain owned by those objects.
    func registerExternalResources(for view: MTKView) {
        register(view.residencySet)

        if let layer = view.layer as? CAMetalLayer {
            register(layer.residencySet)
        }
    }

    private func register(_ residencySet: any MTLResidencySet) {
        let identifier = ObjectIdentifier(residencySet as AnyObject)

        guard registeredExternalSets.insert(identifier).inserted else {
            return
        }

        commandQueue.addResidencySet(residencySet)
    }
}
