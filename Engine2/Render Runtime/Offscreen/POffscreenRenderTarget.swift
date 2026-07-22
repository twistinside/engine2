/// Narrow directed capability for caller-driven exact offscreen rendering.
///
/// The asynchronous, nonisolated contract permits applications and remote
/// tooling to issue an immutable request without depending on a backend actor,
/// queue, view, drawable, or concrete runtime implementation.
nonisolated protocol POffscreenRenderTarget: AnyObject, Sendable {
    func render(_ request: OffscreenRenderRequest) async -> OffscreenRenderOutcome
}
