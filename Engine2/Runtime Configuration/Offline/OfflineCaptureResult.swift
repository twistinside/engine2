/// Completed image artifact paired with the exact Simulation work it observes.
///
/// The raw BGRA image is deliberately released after successful encoding. The
/// encoded artifact retains complete render and encoding provenance, while the
/// advance result retains the immutable final presentation snapshot and exact
/// committed cursor range.
nonisolated struct OfflineCaptureResult: Equatable, Sendable {
    let advanceResult: SimulationAdvanceResult
    let artifact: RenderedImageArtifact
}
