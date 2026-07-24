/// CPU-prepared Metal input for one immutable render frame.
///
/// Each bounded instance carries its already-resolved material and optional
/// model beside it, so GPU packing and ordered drawing cannot drift across
/// parallel arrays or a second resource lookup. Preparing this value resolves
/// all authored content before a caller resets allocators, writes GPU buffers,
/// or begins a Metal 4 command buffer.
@MainActor
struct MetalPreparedFrame {
    let renderFrame: RenderFrame
    let instances: [(
        renderInstance: RenderInstance,
        materialDescription: PBRMaterialDescription,
        model: USDRenderModel?
    )]

    /// Resolves the exact prefix writable by one reusable frame slot.
    init(renderFrame: RenderFrame, resources: MetalResourceStore) {
        self.renderFrame = renderFrame
        self.instances = renderFrame.instances
            .prefix(FrameResources.maximumInstanceCount)
            .map { instance in
                (
                    renderInstance: instance,
                    materialDescription: resources.materialDescription(
                        for: instance.materialID
                    ),
                    model: resources.model(for: instance.meshID)
                )
            }
    }
}
