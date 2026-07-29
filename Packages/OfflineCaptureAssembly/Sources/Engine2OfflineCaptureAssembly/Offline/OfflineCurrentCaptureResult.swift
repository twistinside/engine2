import Engine2
import Engine2AssemblySupport
/// Completed image artifact derived from the exact current presentation value.
///
/// Unlike ``OfflineCaptureResult``, this result records no Simulation advance:
/// the source snapshot is the already completed value selected by the current-
/// cursor request, and its cursor must therefore remain unchanged.
public nonisolated struct OfflineCurrentCaptureResult: Equatable, Sendable {
    public let sourceSnapshot: SimulationPresentationSnapshot
    public let artifact: RenderedImageArtifact

    public init(
        sourceSnapshot: SimulationPresentationSnapshot,
        artifact: RenderedImageArtifact
    ) {
        self.sourceSnapshot = sourceSnapshot
        self.artifact = artifact
    }
}
