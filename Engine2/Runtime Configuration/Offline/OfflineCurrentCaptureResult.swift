/// Completed image artifact derived from the exact current presentation value.
///
/// Unlike ``OfflineCaptureResult``, this result records no Simulation advance:
/// the source snapshot is the already completed value selected by the current-
/// cursor request, and its cursor must therefore remain unchanged.
nonisolated struct OfflineCurrentCaptureResult: Equatable, Sendable {
    let sourceSnapshot: SimulationPresentationSnapshot
    let artifact: RenderedImageArtifact
}
