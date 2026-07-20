/// Selects the renderer-owned visualization produced by the opaque model pass.
///
/// The ordinary surface mode preserves a simple unlit image while foundational
/// render work is under construction. Diagnostic modes reuse the same geometry,
/// transforms, depth state, and draw path so they expose the data the production
/// shader actually receives rather than a parallel debugging implementation.
nonisolated enum RenderOutputMode: Hashable, Sendable {
    case surface
    case viewSpaceNormals
}
