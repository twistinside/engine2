/// Completed JPEG artifact paired with the exact Simulation work it observes.
///
/// The raw BGRA image is deliberately released after successful encoding. The
/// encoded artifact retains complete render and encoding provenance, while the
/// advance result retains the immutable final presentation snapshot and exact
/// committed cursor range.
nonisolated struct OfflineCaptureResult: Equatable, Sendable {
    let advanceResult: SimulationAdvanceResult
    let artifact: RenderedImageArtifact

    /// Creates the terminal value for one fully completed capture workflow.
    init(
        advanceResult: SimulationAdvanceResult,
        artifact: RenderedImageArtifact
    ) {
        self.advanceResult = advanceResult
        self.artifact = artifact
    }
}
