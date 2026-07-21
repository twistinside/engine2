/// Selects the renderer-owned visualization produced by the opaque model pass.
///
/// The ordinary surface mode evaluates the direct-light PBR shader and presents
/// its HDR output through exposure and tone mapping. Diagnostic modes reuse the
/// same geometry, transforms, depth state, HDR target, and draw path so they
/// expose the data the production shader actually receives rather than a
/// parallel debugging implementation.
nonisolated enum RenderOutputMode: Hashable, Sendable {
    case surface
    case viewSpaceNormals
}
