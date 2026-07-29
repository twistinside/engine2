import Engine2
import Engine2AssemblySupport
/// Completed image artifact paired with the exact Simulation work it observes.
///
/// The raw BGRA image is deliberately released after successful encoding. The
/// encoded artifact retains complete render and encoding provenance, while the
/// advance result retains the immutable final presentation snapshot and exact
/// committed cursor range.
public nonisolated struct OfflineCaptureResult: Equatable, Sendable {
    public let advanceResult: SimulationAdvanceResult
    public let artifact: RenderedImageArtifact

    public init(
        advanceResult: SimulationAdvanceResult,
        artifact: RenderedImageArtifact
    ) {
        self.advanceResult = advanceResult
        self.artifact = artifact
    }
}
