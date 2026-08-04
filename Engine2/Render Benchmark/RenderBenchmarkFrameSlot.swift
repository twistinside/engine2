import Metal

/// One member of the production-sized frame ring and its persistent targets.
///
/// Construction allocates every size-dependent attachment before warm-up or
/// measured work begins. The underlying frame semaphore remains the authority
/// for allocator and shared-buffer reuse.
struct RenderBenchmarkFrameSlot {
    let frameResources: FrameResources
    let sceneTarget: MetalHDRSceneTarget
    let targets: RenderBenchmarkTargets

    init(
        frameResources: FrameResources,
        device: any MTLDevice,
        size: RenderPixelSize
    ) throws(RenderBenchmarkError) {
        frameResources.waitUntilAvailable()
        defer {
            frameResources.markAvailable()
        }

        let sceneTarget: MetalHDRSceneTarget
        do {
            sceneTarget = try frameResources.prepareHDRSceneTarget(
                device: device,
                width: size.width,
                height: size.height
            )
        } catch {
            throw .resourceConstructionFailed(String(describing: error))
        }

        self.frameResources = frameResources
        self.sceneTarget = sceneTarget
        self.targets = try RenderBenchmarkTargets(
            device: device,
            size: size
        )
    }
}
