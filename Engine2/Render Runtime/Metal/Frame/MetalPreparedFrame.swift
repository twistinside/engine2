/// CPU-prepared Metal input for one immutable render frame.
///
/// Material descriptions preserve the order of the bounded instance prefix
/// that `FrameResources` can write. Preparing this value resolves all authored
/// content before a caller resets allocators, writes GPU buffers, or begins a
/// Metal 4 command buffer.
@MainActor
struct MetalPreparedFrame {
    let renderFrame: RenderFrame
    let materialDescriptions: [PBRMaterialDescription]
}
