/// Asynchronous CPU transformation consumed by exact artifact workflows.
///
/// The encoder accepts only a completed detached render result and explicit
/// format policy. It does not sample Runtime state, submit GPU work, persist
/// bytes, or advance Simulation. Implementations own their execution context,
/// which keeps scheduling policy out of coordinator initializers and makes
/// deterministic test encoders ordinary protocol values.
public nonisolated protocol PImageArtifactEncoder: Sendable {
    /// Derives one artifact while preserving the supplied render provenance.
    func encode(
        _ result: OffscreenRenderResult,
        as encoding: ImageArtifactEncoding
    ) async throws(ImageArtifactEncoderError) -> RenderedImageArtifact
}
